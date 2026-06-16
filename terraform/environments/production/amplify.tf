# ── Amplify Hosting ───────────────────────────────────────────────────────────
# Manages environment variables injected into the React dashboard at build time.
#
# ONE-TIME IMPORT REQUIRED — the Amplify app was connected to GitHub manually.
# Before the first `terraform apply`, bring it into state:
#
#   terraform import aws_amplify_app.dashboard <AMPLIFY_APP_ID>
#
# Find the App ID: Amplify console → click the app → copy the ID from the URL
# (looks like: d1a2b3c4e5f6g7)

resource "aws_amplify_app" "dashboard" {
  name       = "${var.project}-ui"
  repository = var.amplify_github_repo

  # Login is now server-side (API Lambda validates DB users + issues a JWT), so the
  # dashboard credentials are NOT injected into the public bundle anymore. They are
  # passed to the API Lambda instead as BOOTSTRAP_ADMIN_* (see lambda_api.tf) and
  # only create the first admin user on first login.
  environment_variables = {
    VITE_API_BASE_URL = aws_apigatewayv2_stage.default.invoke_url
  }

  lifecycle {
    # oauth_token is write-only in AWS — Terraform cannot read it back after
    # creation, so ignore it to prevent spurious diffs on every plan.
    # platform and build_spec are managed via amplify.yml in the repo.
    ignore_changes = [oauth_token, platform, build_spec, custom_rule]
  }

  tags = { Name = "${var.project}-ui" }
}
