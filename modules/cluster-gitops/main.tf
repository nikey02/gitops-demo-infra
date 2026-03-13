# partition cluster with namespaces
resource "kubernetes_namespace" "create_namespaces" {
  for_each = {
    for namespace in var.kubernetes_namespaces : namespace => namespace
  }
  metadata {
    name = each.value
  }
}

# apply cert-manager ca secret manifest
resource "kubectl_manifest" "cert_manager_ca_secret" {
  depends_on         = [kubernetes_namespace.create_namespaces]
  override_namespace = "cert-manager"
  yaml_body          = file("./certs/ca-secret.yaml")
}

# install cert-manager helm chart
resource "helm_release" "cert_manager" {
  depends_on       = [kubectl_manifest.cert_manager_ca_secret]
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  name             = "cert-manager"
  namespace        = "cert-manager"
  version          = "v1.16.3"
  create_namespace = true
  cleanup_on_fail  = true
  values = [
    file("./charts/cert-manager/values.yaml")
  ]
}

# Wait until cert-manager CRDs are established before creating ClusterIssuer.
resource "terraform_data" "wait_for_cert_manager_crds" {
  depends_on = [helm_release.cert_manager]

  provisioner "local-exec" {
    command = "kubectl --context k3d-gitops wait --for=condition=Established --timeout=180s crd/clusterissuers.cert-manager.io"
  }
}

# apply cert-manager clusterissuer manifest
resource "kubectl_manifest" "cert_manager_clusterissuer" {
  depends_on         = [terraform_data.wait_for_cert_manager_crds]
  override_namespace = "cert-manager"
  yaml_body          = file("./charts/cert-manager/issuer.yaml")
}

# install ingress-nginx helm chart
resource "helm_release" "ingress_nginx" {
  depends_on       = [kubectl_manifest.cert_manager_clusterissuer]
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  version          = "4.12.1"
  create_namespace = true
  cleanup_on_fail  = true
  values = [
    file("./charts/ingress-nginx/values-cluster-gitops.yaml")
  ]
}

# install argo-cd helm chart
resource "helm_release" "argo_cd" {
  depends_on       = [helm_release.ingress_nginx]
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  name             = "argocd"
  namespace        = "argocd"
  version          = "7.7.22"
  create_namespace = true
  cleanup_on_fail  = true
  values = [
    file("./charts/argo-cd/values.yaml")
  ]
}

# login to ArgoCD instance and add cluster to it
resource "null_resource" "connect_argocd" {
  depends_on = [helm_release.argo_cd]

  provisioner "local-exec" {
    command = <<-EOF
      kubectl --context k3d-dev create serviceaccount argocd-manager -n kube-system --dry-run=client -o yaml | kubectl --context k3d-dev apply -f -
      cat <<'RBAC' | kubectl --context k3d-dev apply -f -
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: argocd-manager-role
      rules:
      - apiGroups:
        - "*"
        resources:
        - "*"
        verbs:
        - "*"
      - nonResourceURLs:
        - "*"
        verbs:
        - "*"
      ---
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: argocd-manager-role-binding
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: argocd-manager-role
      subjects:
      - kind: ServiceAccount
        name: argocd-manager
        namespace: kube-system
      RBAC
      DEV_TOKEN=$(kubectl --context k3d-dev -n kube-system create token argocd-manager)
      cat <<EOF_DEV | kubectl --context k3d-gitops apply -f -
      apiVersion: v1
      kind: Secret
      metadata:
        name: argocd-cluster-dev
        namespace: argocd
        labels:
          argocd.argoproj.io/secret-type: cluster
      type: Opaque
      stringData:
        name: dev
        server: https://k3d-dev-serverlb:6443
        config: |
          {"bearerToken":"$${DEV_TOKEN}","tlsClientConfig":{"insecure":true}}
      EOF_DEV

      kubectl --context k3d-stage create serviceaccount argocd-manager -n kube-system --dry-run=client -o yaml | kubectl --context k3d-stage apply -f -
      cat <<'RBAC' | kubectl --context k3d-stage apply -f -
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: argocd-manager-role
      rules:
      - apiGroups:
        - "*"
        resources:
        - "*"
        verbs:
        - "*"
      - nonResourceURLs:
        - "*"
        verbs:
        - "*"
      ---
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: argocd-manager-role-binding
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: argocd-manager-role
      subjects:
      - kind: ServiceAccount
        name: argocd-manager
        namespace: kube-system
      RBAC
      STAGE_TOKEN=$(kubectl --context k3d-stage -n kube-system create token argocd-manager)
      cat <<EOF_STAGE | kubectl --context k3d-gitops apply -f -
      apiVersion: v1
      kind: Secret
      metadata:
        name: argocd-cluster-stage
        namespace: argocd
        labels:
          argocd.argoproj.io/secret-type: cluster
      type: Opaque
      stringData:
        name: stage
        server: https://k3d-stage-serverlb:6443
        config: |
          {"bearerToken":"$${STAGE_TOKEN}","tlsClientConfig":{"insecure":true}}
      EOF_STAGE

      kubectl --context k3d-prod create serviceaccount argocd-manager -n kube-system --dry-run=client -o yaml | kubectl --context k3d-prod apply -f -
      cat <<'RBAC' | kubectl --context k3d-prod apply -f -
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: argocd-manager-role
      rules:
      - apiGroups:
        - "*"
        resources:
        - "*"
        verbs:
        - "*"
      - nonResourceURLs:
        - "*"
        verbs:
        - "*"
      ---
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: argocd-manager-role-binding
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: argocd-manager-role
      subjects:
      - kind: ServiceAccount
        name: argocd-manager
        namespace: kube-system
      RBAC
      PROD_TOKEN=$(kubectl --context k3d-prod -n kube-system create token argocd-manager)
      cat <<EOF_PROD | kubectl --context k3d-gitops apply -f -
      apiVersion: v1
      kind: Secret
      metadata:
        name: argocd-cluster-prod
        namespace: argocd
        labels:
          argocd.argoproj.io/secret-type: cluster
      type: Opaque
      stringData:
        name: prod
        server: https://k3d-prod-serverlb:6443
        config: |
          {"bearerToken":"$${PROD_TOKEN}","tlsClientConfig":{"insecure":true}}
      EOF_PROD

      kubectl --context k3d-gitops rollout status deployment argocd-server -n argocd --timeout=120s
    EOF
  }
}

# apply argocd git repo manifests
data "kubectl_filename_list" "argocd_repos" {
  pattern = "./charts/argo-cd/repos/*.yaml"
}

resource "kubectl_manifest" "argocd_repos" {
  depends_on         = [null_resource.connect_argocd]
  override_namespace = "argocd"
  count              = length(data.kubectl_filename_list.argocd_repos.matches)
  yaml_body          = file(element(data.kubectl_filename_list.argocd_repos.matches, count.index))
}

resource "kubectl_manifest" "argocd_apps" {
  depends_on         = [kubectl_manifest.argocd_repos]
  override_namespace = "argocd"
  yaml_body          = file("./charts/argo-cd/multi-cluster-apps/applicationset.yaml")
}
