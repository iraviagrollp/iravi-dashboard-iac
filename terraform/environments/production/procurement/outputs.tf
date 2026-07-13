output "procurement_api_endpoint" {
  description = "Procurement API Gateway base URL — set as VITE_API_BASE_URL for procurement-ui"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "procurement_amplify_default_domain" {
  description = "Amplify-assigned domain for the Procurement UI"
  value       = "https://${aws_amplify_app.procurement.default_domain}"
}
