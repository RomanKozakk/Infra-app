variable "azs" {
  type = list(string)
  default = [
    "eu-central-1a",
    "eu-central-1b"
  ]
  description = "List of availability zones"
}
