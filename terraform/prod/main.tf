provider "aws" {
  region  = "eu-north-1"
  version = "~> 2.47"
}

locals {
  environment = "prod"
  url         = "www.skysett.net"
}

resource "aws_s3_bucket" "prod" {
  bucket = "tf-immutable-webapp-prod"

  tags = {
    Name        = "immutable-webapp-prod"
    Environment = local.environment
  }
}


resource "aws_s3_bucket_policy" "public" {
  bucket = aws_s3_bucket.prod.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "Policy1582630604704",
  "Statement": [
    {
      "Sid": "Stmt1582630385628",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "${aws_s3_bucket.prod.arn}/*"
    }
  ]
}
POLICY
}



module "immutable_cloudfront" {
  source = "git@github.com:kleivane/terraform-aws-cloudfront-s3-assets.git?ref=0.3.0"

  bucket_origin_id   = "S3-${aws_s3_bucket.prod.id}"
  bucket_domain_name = aws_s3_bucket.prod.bucket_regional_domain_name
  environment        = local.environment

  aliases = [local.url]
}

data "aws_route53_zone" "primary" {
  name = "skysett.net."
}

module "production_www" {
  source          = "git::https://github.com/cloudposse/terraform-aws-route53-alias.git?ref=0.5.0"
  aliases         = [local.url]
  ipv6_enabled    = true
  parent_zone_id  = data.aws_route53_zone.primary.zone_id
  target_dns_name = module.immutable_cloudfront.distribution.domain_name
  target_zone_id  = module.immutable_cloudfront.distribution.hosted_zone_id
}

module "deployer" {
  source = "../common/modules/terraform-aws-lambda-s3-deployer"

  src_version = "0.1.0"
  api_url     = module.immutable_cloudfront.distribution.domain_name
  bucket = {
    id  = aws_s3_bucket.prod.id
    arn = aws_s3_bucket.prod.arn
  }

  environment = local.environment
}
