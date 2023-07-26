variable "location" {}

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
