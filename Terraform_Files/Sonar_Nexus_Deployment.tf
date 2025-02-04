terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "ba6711d4-708f-4101-8e37-a30695c4c3d4"
  resource_provider_registrations = "none"
}

# Use existing resource group
data "azurerm_resource_group" "rg" {
  name = "Ewis"
}

# Define the public key once (you will use the same path)
locals {
  ssh_public_key = file("C:\Users\MohamedIbrahimHasan\Downloads\SSH_Key.pem")  # Adjust the path as needed
}

# Virtual network for the VMs
resource "azurerm_virtual_network" "vnet" {
  name                = "Project-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Subnet for the VMs
resource "azurerm_subnet" "management_subnet" {
  name                 = "management-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network security group to allow internal traffic
resource "azurerm_network_security_group" "nsg" {
  name                = "management-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH-From-Anywhere"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-All-Traffic-From-Anywhere"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg" {
  subnet_id                 = azurerm_subnet.management_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create a static public IP address resource
resource "azurerm_public_ip" "nexus_public_ip" {
  name                = "nexus-public-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network interface for Nexus VM with a static IP
resource "azurerm_network_interface" "nexus_nic" {
  name                = "nexus-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.5"
    public_ip_address_id          = azurerm_public_ip.nexus_public_ip.id
  }
}

# Create a static public IP address resource
resource "azurerm_public_ip" "sonarqube_public_ip" {
  name                = "sonarqube-public-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network interface for SonarQube VM with a static IP
resource "azurerm_network_interface" "sonarqube_nic" {
  name                = "sonarqube-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.6"
    public_ip_address_id = azurerm_public_ip.sonarqube_public_ip.id
  }
}

# Nexus VM with Username and Password Authentication
resource "azurerm_linux_virtual_machine" "nexus_vm" {
  name                = "nexus-vm"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  disable_password_authentication = "false"
  admin_username = "adminuser"
  admin_password = "0503237439@Mm"  # Set a strong password that meets Azure's requirements
  admin_ssh_key {
    username   = "adminuser"
    public_key = local.ssh_public_key
  }

  network_interface_ids = [
    azurerm_network_interface.nexus_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# SonarQube VM with Username and Password Authentication
resource "azurerm_linux_virtual_machine" "sonarqube_vm" {
  name                = "sonarqube-vm"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  disable_password_authentication = "false"
  admin_ssh_key {
    username   = "adminuser"
    public_key = local.ssh_public_key
  }
  admin_username = "adminuser"
  admin_password = "0503237439@Mm"  # Set a strong password that meets Azure's requirements

  network_interface_ids = [
    azurerm_network_interface.sonarqube_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Output the static private IPs of the VMs
output "nexus_private_ip" {
  value = azurerm_network_interface.nexus_nic.private_ip_address
}

output "sonarqube_private_ip" {
  value = azurerm_network_interface.sonarqube_nic.private_ip_address
}

output "nexus_public_ip" {
  value = azurerm_public_ip.nexus_public_ip.ip_address
}
output "sonarqube_public_ip" {
  value = azurerm_public_ip.sonarqube_public_ip.ip_address
}
