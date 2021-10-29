resource "azurerm_resource_group" "pgsql-rg" {
  name     = "postfacto-db"
  location = "West Europe"
}

module "postgresql" {
  source = "Azure/postgresql/azurerm"

  resource_group_name = azurerm_resource_group.pgsql-rg.name
  location            = azurerm_resource_group.pgsql-rg.location

  server_name                  = "postgresql-${var.org}-${var.app}-${var.environment}"
  sku_name                     = "GP_Gen5_2"
  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  administrator_login          = var.db_login
  administrator_password       = var.db_password
  server_version               = "11"
  ssl_enforcement_enabled      = false
  db_names                     = ["postfacto-staging-db"]
  db_charset                   = "UTF8"
  db_collation                 = "English_United States.1252"

  firewall_rule_prefix = "firewall-"
  firewall_rules = [
    { name = "my-home-ip", start_ip = "213.127.120.249", end_ip = "213.127.120.249" }
  ]

  vnet_rule_name_prefix = "postgresql-vnet-rule-"
  vnet_rules = [
    { name = "aks-subnet", subnet_id = module.vnet.vnet_subnets[0] },
  ]

  tags = {
    Environment = "Staging",
  }

  postgresql_configurations = {
    backslash_quote = "on",
  }

  depends_on = [azurerm_resource_group.pgsql-rg]
}