data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = { Name = "${var.project}-ec2-role" }
}

# ---------------- AWS-managed policies ----------------
# Session Manager (shell access without SSH)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch agent (logs and metrics, only active if the agent is installed)
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ---------------- Our own least-privilege policy ----------------
data "aws_iam_policy_document" "app" {
  statement {
    sid       = "ReadDbSecretOnly"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.secret_arn_pattern]
  }

  statement {
    sid       = "ListAppBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.app_bucket_arn]
  }

  statement {
    sid       = "ReadAppBucketObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${var.app_bucket_arn}/*"]
  }

  statement {
    sid       = "WriteUploadsPrefixOnly"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${var.app_bucket_arn}/uploads/*"]
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "${var.project}-ec2-app-access"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.app.json
}

# ---------------- Instance profile (how the role attaches to EC2) ----------------
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = { Name = "${var.project}-ec2-profile" }
}