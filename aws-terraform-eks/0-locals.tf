## We have updated the file name as 0-locals.tf, from 0 it represent that in which order we have created the resources. 
### Local values are like a function's temporary local variables.  #210034742139

locals {
  env         = "staging" # It can be development and production also.
  region      = "us-east-2"
  zone1       = "us-east-2a"
  zone2       = "us-east-2b"
  eks_name    = "demo-eks"
  eks_version = "1.29"
}