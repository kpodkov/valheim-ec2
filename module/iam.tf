resource "aws_iam_role" "valheim" {
  name = "${local.name}-server"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : "sts:AssumeRole",
        Principal : {
          Service : "ec2.amazonaws.com"
        },
        Effect : "Allow",
        Sid : ""
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_instance_profile" "valheim" {
  role = aws_iam_role.valheim.name
}

resource "aws_iam_policy" "valheim" {
  name        = "${local.name}-server"
  description = "Allows the Valheim server to interact with various AWS services"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "s3:Put*",
          "s3:Get*",
          "s3:List*"
        ],
        Resource : [
          "arn:aws:s3:::${aws_s3_bucket.valheim.id}",
          "arn:aws:s3:::${aws_s3_bucket.valheim.id}/"
        ]
      },
      {
        Effect : "Allow",
        Action : ["ec2:DescribeInstances"],
        Resource : ["*"]
      }
    ]
  })
}

resource "aws_iam_policy" "valheim_cname" {
  count = var.domain != "" ? 1 : 0

  name        = "${local.name}-cname"
  description = "Allows the Valheim server to update its own CNAME when recreated"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : ["route53:ChangeResourceRecordSets"],
        Effect : "Allow",
        Resource : ["arn:aws:route53:::hostedzone/${data.aws_route53_zone.selected[0].zone_id}"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "valheim" {
  role       = aws_iam_role.valheim.name
  policy_arn = aws_iam_policy.valheim.arn
}

resource "aws_iam_role_policy_attachment" "valheim_cname" {
  count = var.domain != "" ? 1 : 0

  role       = aws_iam_role.valheim.name
  policy_arn = aws_iam_policy.valheim_cname[0].arn
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.valheim.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#tfsec:ignore:aws-iam-enforce-mfa
resource "aws_iam_group" "valheim_users" {
  name = "${local.name}-users"
  path = "/users/"
}

resource "aws_iam_policy" "valheim_users" {
  name        = "${local.name}-user"
  description = "Allows Valheim users to start the server"
  policy = jsonencode({
    Version = "2012-10-17"
    "Statement" : [
      {
        Effect : "Allow",
        Action : ["ec2:StartInstances"],
        Resource : "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.valheim.id}",
      },
      {
        Effect : "Allow",
        Action : [
          "cloudwatch:DescribeAlarms",
          "ec2:DescribeAddresses",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstances",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeNetworkInterfaces",
          "iam:ChangePassword"
        ]
        Resource : "*"
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "valheim_users" {
  group      = aws_iam_group.valheim_users.name
  policy_arn = aws_iam_policy.valheim_users.arn
}

resource "aws_iam_user" "valheim_user" {
  #checkov:skip=CKV2_AWS_22:We want users to be able to access the console
  for_each = var.admins

  name          = each.key
  path          = "/"
  force_destroy = true
  tags          = local.tags
}

resource "aws_iam_user_login_profile" "valheim_user" {
  for_each = aws_iam_user.valheim_user

  user    = aws_iam_user.valheim_user[each.key].name
  pgp_key = "keybase:${var.keybase_username}"
}

resource "aws_iam_user_group_membership" "valheim_users" {
  for_each = aws_iam_user.valheim_user

  user   = aws_iam_user.valheim_user[each.key].name
  groups = [aws_iam_group.valheim_users.name]
}

output "valheim_user_passwords" {
  value = { for i in aws_iam_user_login_profile.valheim_user : i.user => i.encrypted_password }
}
