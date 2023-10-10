output "kubeconfig" {
    description = "kubernetes config file to access ELS API server"
    value = local.k8s_kubeconfig
    sensitive = false
}

output "asg_name_map" {
    description = "Autoscaling group name for cluster autoscaling(CA)"
    value = local.asg_name_map
}

output "cluster_id" {
    description = "Name of the cluster"
    value = aws_eks_cluster.eks_cluster.id
}

output "cluster_version" {
    description = "Autoscaling group name for cluster autoscaling(CA)"
    value = aws_eks_cluster.eks_cluster.platform_version
}

output "endpoint" {
    description = "Endpoint for your Kubernetes API server"
    value = aws_eks_cluster.eks_cluster.endpoint
}

output "openid_connect_provider_arn" {
    description = "openid_connect_provider arn"
    value = aws_iam_openid_connect_provider.eks_cluster.arn
}

output "openid_connect_provider_url" {
    description = "openid_connect_provider url"
    value = aws_eks_cluster.eks_cluster.identity.0.oidc.0.issuer
}

output "cluster_security_group_id" {
    description = "EKS cluster security group id"
    value = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}

output "cluster_ca_certificate" {
    description = "Base64 encoded certificate data required to communicate with your cluster"
    value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
    sensitive = true
}

output "service_ipv4_cidr" {
    description = "The CIDR block to assign Kubernetes pod and service IP addresses from"
    value = aws_eks_cluster.eks_cluster.kubernetes_network_config[0].service_ipv4_cidr
}