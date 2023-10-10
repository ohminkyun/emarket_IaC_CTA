terraform {
  /* 업로드 예외 신청전 comment 처리
  backend "s3" {
    bucket = "emarket-terraform-bucket"
    key    = "emarket/terraform.tfstate"
    region = "ap-northeast-2"
  }
  */
  required_version = ">=1.1.3"
}

provider "aws" {
  region = var.region_name
}