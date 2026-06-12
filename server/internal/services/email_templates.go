package services

import "fmt"

// WrapInEmailTemplate wraps body content in a clean HTML email layout.
func WrapInEmailTemplate(subject, bodyContent string) string {
	return fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 0; background: #f4f4f7; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
    .container { max-width: 580px; margin: 0 auto; padding: 20px; }
    .card { background: #ffffff; border-radius: 8px; padding: 32px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
    .header { text-align: center; padding-bottom: 20px; border-bottom: 2px solid #e8e8eb; margin-bottom: 24px; }
    .header h1 { color: #1a1a2e; font-size: 20px; margin: 0; }
    .header .subtitle { color: #6b7280; font-size: 13px; margin-top: 4px; }
    .content { color: #374151; font-size: 15px; line-height: 1.6; }
    .footer { text-align: center; padding-top: 20px; margin-top: 24px; border-top: 1px solid #e8e8eb; color: #9ca3af; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="card">
      <div class="header">
        <h1>%s</h1>
        <div class="subtitle">Sainath Society / सोसायटी मित्र</div>
      </div>
      <div class="content">
        %s
      </div>
      <div class="footer">
        This is an automated notification from Sainath Society Management.<br>
        हा साईनाथ सोसायटी व्यवस्थापनाचा स्वयंचलित संदेश आहे.
      </div>
    </div>
  </div>
</body>
</html>`, subject, bodyContent)
}
