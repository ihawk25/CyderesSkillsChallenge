/*
 * Backend State File
 */

terraform {
  backend "s3" {
    bucket = "539168743082-tfstate"
	key    = "us-west-2.tfstate"
	region = "us-west-2"
	acl    = "bucket-owner-full-control"
  }
}
