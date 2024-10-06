
# Here we update the providers information.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.66.0"
    }
  }
}

provider "aws" {
  region = local.region # here we are getting the region form the locals. We updated some local variable in "0-locals.tf" file. 
}



