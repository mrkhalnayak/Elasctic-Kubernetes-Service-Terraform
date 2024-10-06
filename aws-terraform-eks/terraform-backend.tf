

terraform {
  backend "s3" {
    bucket  = "terraform-backend-bucket-shri-12"
    key     = "staging/terraform.tfstate" # Path within the bucket
    region  = "us-east-2"                 # Region of the bucket
    encrypt = true                        # Optional, for server-side encryption
  }
}