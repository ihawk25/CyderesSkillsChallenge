/*
 * Backend State File
 */

terraform {
  backend "s3" {
    bucket = "539168743082-terraform"
	key    = "us-west-1.tfstate"
	region = "us-west-1"
	acl    = "bucket-owner-full-control"
  }
}
