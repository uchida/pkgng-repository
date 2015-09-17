variable "bucket_name" {}

resource "aws_s3_bucket" "main" {
  bucket = "${var.bucket_name}"
  acl = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  tags {
    Name = "${var.bucket_name}"
    Environment = "pkgng"
  }
}

resource "aws_iam_user" "main" {
    name = "pkgng-s3-sync"
    path = "/pkgng/"
}

resource "aws_iam_access_key" "main" {
    user = "${aws_iam_user.main.name}"
}

resource "template_file" "policy" {
  filename = "${path.module}/s3-sync-policy.json"
  vars {
    bucket = "${aws_s3_bucket.main.id}"
  }
}

resource "aws_iam_user_policy" "main" {
    name = "pkgng-s3-sync"
    user = "${aws_iam_user.main.name}"
    policy = "${template_file.policy.rendered}"
}
