locals {
  name          = "${var.org}-${var.app}-${var.environment}-${random_id.id.hex}"
  name_nospaces = replace(local.name, "-", "")
  hex_id        = random_id.id.hex
}