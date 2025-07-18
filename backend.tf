/*
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-backend-kassab"  
    key            = "dev/terraform.tfstate"        
    region         = "us-east-1"                    
    encrypt        = true                          
    dynamodb_table = "terraform-state-locks"
  }
}
*/