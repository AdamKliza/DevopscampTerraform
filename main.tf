##-- Variables

variable "resource_group_name" {
  type = string
  default = "DevOps"
}

variable "environment" {
  type = string
  default = "Dev"
}

variable "project" {
    type = string
    default = "DevOps"
}

variable "userlogin" {
    type = string
    default = "devops"
}

variable "userpassword" {
    type = string
    default = "P@ssw0rd!@#"
}
  
variable "packages_to_install" {
  type = list(string)
  default = ["git", "python3", "python3-pip","apache2"]
}
  


##-- provider

provider "azurerm" {
  features {}
}

##-- Resource Group

data "azurerm_resource_group" "RG" {
  name = var.resource_group_name
}
##-- Virtual Network

resource "azurerm_virtual_network" "vnet" {
  name = "${var.project}-${var.environment}-vnet"
  resource_group_name = data.azurerm_resource_group.RG.name
  location = data.azurerm_resource_group.RG.location
  address_space       = ["10.0.0.0/16"]
  tags = {
    environment = var.environment
  }
}
##-- Subnet

resource "azurerm_subnet" "subnet" {
  name                 = "${var.project}-${var.environment}-subnet"
  resource_group_name  = data.azurerm_resource_group.RG.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

##-- Network interface
resource "azurerm_public_ip" "pip" {
  name                = "${var.project}-${var.environment}-publicip"
  resource_group_name = data.azurerm_resource_group.RG.name
  location            = data.azurerm_resource_group.RG.location
  allocation_method   = "Static"

  tags = {
    environment = var.environment
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.project}-${var.environment}-nic"
  location            = data.azurerm_resource_group.RG.location
  resource_group_name = data.azurerm_resource_group.RG.name

  ip_configuration {
    name                          = "${var.project}-${var.environment}-ip-config"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
    tags = {
    environment = var.environment
  }
}

##-- Security Group
resource "azurerm_network_security_group" "SecurityGr" {
  name                = "${var.project}-${var.environment}-SecurityGroup"
  location            = data.azurerm_resource_group.RG.location
  resource_group_name = data.azurerm_resource_group.RG.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "22"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
  }
}

##-- Virtual Machine

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.project}-${var.environment}-vm"
  location              = data.azurerm_resource_group.RG.location
  resource_group_name   = data.azurerm_resource_group.RG.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_B1s"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Debian"
    offer     = "debian-12-daily"
    sku       = "12"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "${var.project}-${var.environment}-vm"
    admin_username = var.userlogin
    admin_password = var.userpassword
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = var.environment
  }
  
    connection {
    type     = "ssh"
    user     = var.userlogin
    password = var.userpassword
    host     = azurerm_public_ip.pip.ip_address
  }
    provisioner "remote-exec" {
    inline    = ["sudo apt update",
                "sudo apt install -y ${join(" ", var.packages_to_install)} -y",
                "echo 'Hello World' | sudo tee /var/www/html/index.html"]
  }
}

 
output "public_ip_address" {
  description = "Public IP Address of the VM"
  value       = azurerm_public_ip.pip.ip_address
}
output "WEB" {
  description = "WEb"
  value       = "http://${azurerm_public_ip.pip.ip_address}/"
}

