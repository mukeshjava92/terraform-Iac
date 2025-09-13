resource "azurerm_resource_group" "rg" {
  name = var.resource_group_name
  location = var.location
}
resource "azurerm_kubernetes_cluster" "ak8s" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.dns_prefix

  default_node_pool {
    name       = "agentpool"
    node_count = var.agent_count
    vm_size    = "Standard_D2_v2"
  }

 identity {
    type = "SystemAssigned"
 }

  network_profile {
    load_balancer_sku = "standard"
    network_plugin    = "kubenet"
  }

  tags = {
    Environment = "Staging"
  }
}
