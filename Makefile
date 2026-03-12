SHELL := /bin/sh

help: ## Usage: 'make <target>' where target is: single, up, down, all, single, destroy, clean.
	@egrep '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

destroy: ## Destroys k3s clusters
	@k3d cluster delete --all

clean: ## Destroys clusters and cleans Terraform leftovers
	@k3d cluster delete --all && rm -rf .terraform* terraform.*

up: ## Starts all k3s clusters
	@k3d cluster start k3d --all

down: ## Stops all k3s clusters
	@k3d cluster stop k3d --all

cluster: clean ## Provisions single k3s cluster
	@k3d cluster create                                                                  \
		--servers 1                                                                      \
		--api-port host.k3d.internal:6443                                                \
		--image rancher/k3s:v1.32.2-k3s1                                                 \
		--token superSecretToken                                                         \
		--timeout 60s                                                                    \
		--port 443:443@loadbalancer:0                                                    \
		--k3s-arg "--cluster-cidr=10.1.0.0/16@server:0"                                  \
		--k3s-arg "--service-cidr=10.0.0.0/16@server:0"                                  \
		--k3s-arg "--etcd-disable-snapshots@server:0"                                    \
		--k3s-arg "--disable=traefik@server:0"                                           \
		--k3s-arg "--disable=network-policy@server:0"                                    \
		--k3s-arg "--disable=cloud-controller@server:0"                                  \
		--kubeconfig-update-default                                                      \
		--wait single;                                                                   \

cluster-tf: ## Applies module 'cluster-single'
	@terraform init -upgrade                                                             \
	 && terraform apply -parallelism=100 -auto-approve -target=module.cluster-single

cluster-all: clean cluster cluster-tf ## Provisions single k3s cluster, runs Terraform and installs ArgoCD

.ONESHELL:
multi-cluster: clean ## Create k3s multi-cluster setup, more info https://github.com/k3d-io/k3d/discussions/1015
	@k3d cluster create                                                                  \
		--servers 1                                                                      \
		--api-port host.k3d.internal:64432                                               \
		--network multicluster                                                           \
		--image rancher/k3s:v1.32.2-k3s1                                                 \
		--token superSecretToken                                                         \
		--timeout 60s                                                                    \
		--port 4432:443@loadbalancer:0                                                   \
		--k3s-arg "--cluster-cidr=10.1.0.0/16@server:0"                                  \
		--k3s-arg "--service-cidr=10.0.0.0/16@server:0"                                  \
		--k3s-arg "--etcd-disable-snapshots@server:0"                                    \
		--k3s-arg "--disable=traefik@server:0"                                           \
		--k3s-arg "--disable=network-policy@server:0"                                    \
		--k3s-arg "--disable=cloud-controller@server:0"                                  \
		--kubeconfig-update-default                                                      \
		--wait dev;                                                                      \
																						 \
	k3d cluster create                                                                   \
		--servers 1                                                                      \
		--api-port host.k3d.internal:64433                                               \
		--network multicluster                                                           \
		--image rancher/k3s:v1.32.2-k3s1                                                 \
		--token superSecretToken                                                         \
		--timeout 60s                                                                    \
		--port 4433:443@loadbalancer:0                                                   \
		--k3s-arg "--cluster-cidr=10.1.0.0/16@server:0"                                  \
		--k3s-arg "--service-cidr=10.0.0.0/16@server:0"                                  \
		--k3s-arg "--etcd-disable-snapshots@server:0"                                    \
		--k3s-arg "--disable=traefik@server:0"                                           \
		--k3s-arg "--disable=network-policy@server:0"                                    \
		--k3s-arg "--disable=cloud-controller@server:0"                                  \
		--kubeconfig-update-default                                                      \
		--wait stage;                                                                    \
																						 \
	k3d cluster create                                                                   \
		--servers 1                                                                      \
		--api-port host.k3d.internal:64434                                               \
		--network multicluster                                                           \
		--image rancher/k3s:v1.32.2-k3s1                                                 \
		--token superSecretToken                                                         \
		--timeout 60s                                                                    \
		--port 4434:443@loadbalancer:0                                                   \
		--k3s-arg "--cluster-cidr=10.1.0.0/16@server:0"                                  \
		--k3s-arg "--service-cidr=10.0.0.0/16@server:0"                                  \
		--k3s-arg "--etcd-disable-snapshots@server:0"                                    \
		--k3s-arg "--disable=traefik@server:0"                                           \
		--k3s-arg "--disable=network-policy@server:0"                                    \
		--k3s-arg "--disable=cloud-controller@server:0"                                  \
		--kubeconfig-update-default                                                      \
		--wait prod;                                                                     \
																						 \
	k3d cluster create                                                                   \
		--servers 1                                                                      \
		--api-port host.k3d.internal:64431                                               \
		--network multicluster                                                           \
		--image rancher/k3s:v1.32.2-k3s1                                                 \
		--token superSecretToken                                                         \
		--timeout 60s                                                                    \
		--port 4431:443@loadbalancer:0                                                   \
		--k3s-arg "--cluster-cidr=10.1.0.0/16@server:0"                                  \
		--k3s-arg "--service-cidr=10.0.0.0/16@server:0"                                  \
		--k3s-arg "--etcd-disable-snapshots@server:0"                                    \
		--k3s-arg "--disable=traefik@server:0"                                           \
		--k3s-arg "--disable=network-policy@server:0"                                    \
		--k3s-arg "--disable=cloud-controller@server:0"                                  \
		--kubeconfig-update-default                                                      \
		--wait gitops                                                                    \

cluster-dev: ## Applies module 'cluster-dev'
	@terraform init -upgrade                                                             \
	 && terraform apply -parallelism=100 -auto-approve -target=module.cluster-dev

cluster-stage: ## Applies module 'cluster-stage'
	@terraform init -upgrade                                                             \
	 && terraform apply -parallelism=100 -auto-approve -target=module.cluster-stage

cluster-prod: ## Applies module 'cluster-prod'
	@terraform init -upgrade                                                             \
	 && terraform apply -parallelism=100 -auto-approve -target=module.cluster-prod

cluster-gitops: ## Applies module 'cluster-gitops'
	@terraform init -upgrade                                                             \
	 && terraform apply -parallelism=100 -auto-approve -target=module.cluster-gitops

dev-clusters: cluster-dev cluster-stage cluster-prod cluster-gitops ## Applies all dev cluster modules

multi-all: clean multi-cluster dev-clusters ## Create k3s multi-cluster setup, runs Terarform and installs ArgoCD
