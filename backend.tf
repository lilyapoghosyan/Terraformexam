terraform {
  backend "s3" {
    bucket = "myappfullexam"
    region = "eu-central-1"
    key    = "keyforapp"
  }
}
