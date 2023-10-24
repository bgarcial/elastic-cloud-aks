locals {
    
    tags = merge(
        { "Environment" = terraform.workspace },
        var.vnet_tags
    )
    virtual_network_name   = terraform.workspace == "prod" ? "prod-${var.org}-${var.app}" : "stag-${var.org}-${var.app}"

}