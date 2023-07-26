
##Connect Terraform with AzureCLI##

provider "azurerm" {
  version = "=1.43.0"
}

variable "prefix" {
  type    = string
  default = "Prod"
}

variable "sku" {
  default = {
    Test = "16.04-LTS"
    Prod = "18.04-LTS"
  }
}

##Create a Resource Group##

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = "${var.prefix}-internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "publicip" {
  name                = "${var.prefix}-TFPublicIP"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
}


resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "${var.prefix}-myNetworkSecurityGroup"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  #    security_rule {
  #        name                       = "RDP"
  #        priority                   = 300
  #        direction                  = "Inbound"
  #        access                     = "Allow"
  #        protocol                   = "Tcp"
  #        source_port_range          = "*"
  #        destination_port_range     = "3389"
  #        source_address_prefix      = "*"
  #        destination_address_prefix = "*"
  #    }


  tags = {
    environment = "Terraform Demo"
  }
}

resource "azurerm_network_interface" "main" {
  name                      = "${var.prefix}-nic"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

resource "azurerm_storage_account" "example" {
  name                     = "stotnameriz"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "staging"
  }
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}-vm"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_DS1_v2"

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = lookup("${var.sku}", "${var.prefix}")
    version   = "latest"
  }

  #  storage_image_reference {
  #    publisher = "MicrosoftWindowsServer"
  #    offer     = "WindowsServer"
  #    sku       = "2016-Datacenter-Server-Core"
  #    version   = "latest"
  #  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  #  os_profile_windows_config {
  #    enable_automatic_upgrades = false
  #  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      host     = azurerm_public_ip.publicip.ip_address
      user     = "testadmin"
      password = "Password1234!"
    }

    inline = [
      "sudo mkdir /var/testing"
    ]
  }
  tags = {
    environment = "staging"
  }
}

output "ip" {
  value       = azurerm_public_ip.publicip.ip_address
  description = "The public IP for Virtual Machine"
}
