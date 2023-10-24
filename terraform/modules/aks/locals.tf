locals {
    
    tags = merge(
        { "Environment" = terraform.workspace },
        var.tags
    )
    kubernetes_cluster_name   = terraform.workspace == "prod" ? "prod-${var.org}-${var.app}" : "stag-${var.org}-${var.app}"
}