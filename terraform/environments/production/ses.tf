# ── SES — alerts sender identity ───────────────────────────────────────────────
# Domain identity + DKIM for noreply@<alerts_domain>.
# The alerts_evaluator Lambda uses this identity to send balance-alert emails.
#
# MANUAL STEPS REQUIRED AFTER terraform apply:
#
# 1. DNS verification — add the CNAME records that Terraform outputs to your
#    domain's DNS provider (e.g. Route 53, GoDaddy, Cloudflare):
#
#      terraform output ses_dkim_tokens
#
#    Each token produces ONE CNAME:
#      Name:   <token>._domainkey.<alerts_domain>
#      Value:  <token>.dkim.amazonses.com
#    Add all three CNAMEs. SES verifies automatically within ~72 h.
#
# 2. SES production access — new AWS accounts start in the SES sandbox where
#    outbound email is limited to verified addresses only.
#    Request production access (removes sandbox restrictions):
#      AWS Console → SES → Account dashboard → Request production access
#    Fill in the support case: use case = transactional, daily sending volume,
#    and confirm CAN-SPAM compliance. Approval typically takes 1-2 business days.
#    Until approved, add recipient addresses as verified identities in SES to
#    test in sandbox mode.

# ── SES domain identity ───────────────────────────────────────────────────────

resource "aws_ses_domain_identity" "alerts" {
  domain = var.alerts_domain
}

# ── DKIM signing ──────────────────────────────────────────────────────────────
# Generates 3 DKIM CNAME records (output below). Add them to DNS to complete
# domain verification and enable DKIM signing for outbound emails.

resource "aws_ses_domain_dkim" "alerts" {
  domain = aws_ses_domain_identity.alerts.domain
}

# ── SES configuration set ─────────────────────────────────────────────────────
# Lets us track deliveries/bounces and scope IAM to this set.

resource "aws_ses_configuration_set" "alerts" {
  name = "${var.project}-alerts"
}

# ── Outputs — DNS records to add to your domain registrar ────────────────────

output "ses_domain_verification_token" {
  description = "Add this as a TXT record at _amazonses.<alerts_domain> to verify the SES domain identity. Name: _amazonses.<domain>  Value: <token>"
  value       = aws_ses_domain_identity.alerts.verification_token
}

output "ses_dkim_tokens" {
  description = "Add three CNAME records to DNS. For each token T: Name = T._domainkey.<domain>  Value = T.dkim.amazonses.com"
  value       = aws_ses_domain_dkim.alerts.dkim_tokens
}

output "ses_identity_arn" {
  description = "SES domain identity ARN — scoped in the alerts_evaluator IAM policy for SendEmail"
  value       = aws_ses_domain_identity.alerts.arn
}
