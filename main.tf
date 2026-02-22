# 1. GENERATE A UNIQUE SUFFIX
resource "random_id" "suffix" {
  byte_length = 4
}

# 2. CREATE THE LAMBDA EXECUTION ROLE
resource "aws_iam_role" "iam_for_lambda" {
  name = "ai_pipeline_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# 3. ATTACH PERMISSIONS (AI & DATABASE)
resource "aws_iam_role_policy" "lambda_ai_policy" {
  name = "lambda_rekognition_policy"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rekognition:DetectLabels",
          "s3:GetObject",
          "dynamodb:PutItem",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# 4. THE DATABASE
resource "aws_dynamodb_table" "image_labels" {
  name         = "ImageAnalysisResults"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ImageId"

  attribute {
    name = "ImageId"
    type = "S"
  }
}

# 5. THE S3 BUCKET
resource "aws_s3_bucket" "image_upload" {
  bucket = "my-ai-image-uploads-${random_id.suffix.hex}"
}

# 6. THE LAMBDA FUNCTION (The "Worker")
resource "aws_lambda_function" "ai_analyzer" {
  filename         = "lambda.zip"
  function_name    = "AIImageProcessor"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("lambda.zip")
}

# 7. THE "HALL PASS" (Permission for S3 to call Lambda)
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai_analyzer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.image_upload.arn
}

# 8. THE "WIRE" (Triggering the notification)
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.image_upload.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.ai_analyzer.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_s3_bucket_cors_configuration" "image_upload_cors" {
  bucket = aws_s3_bucket.image_upload.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"] # For development, this allows localhost to upload
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# 1. THE NEW "READER" LAMBDA
resource "aws_lambda_function" "fetch_labels" {
  filename      = "fetch_labels.zip"
  function_name = "FetchImageLabels"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "fetch_labels.lambda_handler"
  runtime       = "python3.9"

  # THIS IS THE KEY LINE:
  # It tells Terraform to check the actual content of the zip file
  source_code_hash = filebase64sha256("fetch_labels.zip")
}

# 2. API GATEWAY (The "Front Door")
resource "aws_apigatewayv2_api" "web_api" {
  name          = "ImageAI-API"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]  # Back to the wildcard
    allow_methods = ["GET", "POST", "OPTIONS", "PUT"]
    allow_headers = ["*"]
    max_age       = 300
  }
}

# 3. CONNECT API TO LAMBDA
resource "aws_apigatewayv2_integration" "lambda_link" {
  api_id           = aws_apigatewayv2_api.web_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.fetch_labels.invoke_arn
}

resource "aws_apigatewayv2_route" "get_labels" {
  api_id    = aws_apigatewayv2_api.web_api.id
  route_key = "GET /labels"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_link.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.web_api.id
  name        = "$default"
  auto_deploy = true
}

# 4. PERMISSION FOR API TO CALL LAMBDA
resource "aws_lambda_permission" "api_gw" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_labels.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.web_api.execution_arn}/*/*"
}

output "api_url" {
  value = aws_apigatewayv2_api.web_api.api_endpoint
}

# 1. Define the "Read Only" Permission
resource "aws_iam_policy" "dynamodb_read_policy" {
  name        = "LambdaDynamoDBReadPolicy"
  description = "Allows Lambda to read from the ImageAnalysisResults table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Effect   = "Allow"
        # CHANGE THIS LINE to match your table's nickname:
        Resource = aws_dynamodb_table.image_labels.arn
      }
    ]
  })
}

# 2. Attach the permission to your existing Lambda role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_read" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.dynamodb_read_policy.arn
}

# 1. ZIP THE SIGNER CODE (Add this near your other data sources)
data "archive_file" "signer_zip" {
  type        = "zip"
  source_file = "${path.module}/signer.py" # Use the explicit path
  output_path = "${path.module}/signer.zip"
}

# 2. CREATE THE SIGNER LAMBDA
resource "aws_lambda_function" "signer" {
  filename         = data.archive_file.signer_zip.output_path
  function_name    = "S3LinkSigner"
  role             = aws_iam_role.iam_for_lambda.arn # Reuse your role
  handler          = "signer.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.signer_zip.output_base64sha256
}

# 3. GIVE PERMISSION TO S3 (The Lambda needs to "PutObject")
resource "aws_iam_role_policy" "s3_write_policy" {
  name = "LambdaS3WritePolicy"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:PutObject"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.image_upload.arn}/*" # Match your bucket resource name
      }
    ]
  })
}

# 4. CONNECT API TO SIGNER LAMBDA
resource "aws_apigatewayv2_integration" "signer_link" {
  api_id           = aws_apigatewayv2_api.web_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.signer.invoke_arn
}

resource "aws_apigatewayv2_route" "sign_route" {
  api_id    = aws_apigatewayv2_api.web_api.id
  route_key = "POST /sign"
  target    = "integrations/${aws_apigatewayv2_integration.signer_link.id}"
}

# 5. PERMISSION FOR API TO CALL SIGNER
resource "aws_lambda_permission" "api_gw_signer" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.signer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.web_api.execution_arn}/*/*"
}

