resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_security_group" "example" {
  name        = "example"
  description = "Very complex Security Group for testing"
  vpc_id      = aws_vpc.main.id

  tags = {
    "Name" = "example"
  }
}

resource "aws_security_group_rule" "example_rule" {
  security_group_id = aws_security_group.example.id
  description       = "Allow all traffic from Internet which will make trivy throw an error"

  type      = "ingress"
  from_port = "0"
  to_port   = "65535"
  protocol  = "tcp"

  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}


resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_managed_disk" "example" {
  name                 = "acctestmd"
  location             = "West Europe"
  resource_group_name  = azurerm_resource_group.example.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1"

  encryption_settings {
    enabled = false
  }
}
