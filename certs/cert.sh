#!/bin/sh

COMMON_NAME="gitops.local"
OPENSSL=$(which openssl)

# Detect openssl.cnf location across distros/OS
if [ -f "/etc/ssl/openssl.cnf" ]; then
    OPENSSL_CNF="/etc/ssl/openssl.cnf"
elif [ -f "/etc/pki/tls/openssl.cnf" ]; then
    OPENSSL_CNF="/etc/pki/tls/openssl.cnf"
elif [ -f "/usr/local/etc/openssl@3/openssl.cnf" ]; then
    OPENSSL_CNF="/usr/local/etc/openssl@3/openssl.cnf"
elif [ -f "/usr/local/etc/openssl/openssl.cnf" ]; then
    OPENSSL_CNF="/usr/local/etc/openssl/openssl.cnf"
else
    echo "ERROR: Could not find openssl.cnf. Set OPENSSL_CNF manually." >&2
    exit 1
fi

OPENSSL_PARAMS="-new -nodes -sha256 -days 3650 -reqexts v3_req -extensions v3_ca -config ${OPENSSL_CNF}"
OPENSSL_SUBJ="/CN=${COMMON_NAME}"
CA_KEY="ca.key"
CA_CERT="ca.crt"

${OPENSSL} genrsa -out ${CA_KEY} 2048
${OPENSSL} req -x509 ${OPENSSL_PARAMS} -subj ${OPENSSL_SUBJ} -key ${CA_KEY} -out ${CA_CERT}

kubectl --dry-run=client create secret tls ca-key-pair --cert=${CA_CERT} --key=${CA_KEY} --namespace=cert-manager -oyaml > ca-secret.yaml

# Trust the CA certificate (OS-specific)
OS=$(uname -s)
if [ "${OS}" = "Darwin" ]; then
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ${CA_CERT}
elif [ "${OS}" = "Linux" ]; then
    sudo cp ${CA_CERT} /usr/local/share/ca-certificates/gitops-local.crt
    sudo update-ca-certificates
else
    echo "WARNING: Unknown OS '${OS}'. Skipping system trust store update." >&2
fi
