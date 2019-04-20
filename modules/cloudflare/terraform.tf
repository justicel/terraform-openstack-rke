variable "cloudflare_email" {
  description = "E-mail address to use for API authentication"
}

variable "cloudflare_token" {
  description = "Token to use for API authentication"
}

provider "cloudflare" {
  version = "~>1.0"
  email   = "${var.cloudflare_email}"
  token   = "${var.cloudflare_token}"
}
