provider "aws" {
  region     = "ap-south-1"
  access_key = ""
  secret_key = ""
}
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "logging" {
  bucket = "access-logging-bucket11112"
}

data "aws_iam_policy_document" "logging_bucket_policy" {
  statement {
    principals {
      identifiers = ["logging.s3.amazonaws.com"]
      type        = "Service"
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logging.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "logging" {
  bucket = aws_s3_bucket.logging.bucket
  policy = data.aws_iam_policy_document.logging_bucket_policy.json
}

resource "aws_s3_bucket" "example" {
  bucket = "example-bucket11113"
}

resource "aws_s3_bucket_logging" "example" {
  bucket = aws_s3_bucket.example.bucket

  target_bucket = aws_s3_bucket.logging.bucket
  target_prefix = "log/"
  target_object_key_format {
    partitioned_prefix {
      partition_date_source = "EventTime"
    }
  }
}