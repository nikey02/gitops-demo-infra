output "argocd_port_forward_command" {
  description = "Command to access Argo CD server from the gitops cluster"
  value       = "kubectl --context k3d-gitops -n argocd port-forward --address 0.0.0.0 svc/argocd-server 8080:80"
}
