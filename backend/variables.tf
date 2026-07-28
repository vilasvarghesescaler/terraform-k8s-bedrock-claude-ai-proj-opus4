variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "short_name" {
  description = "Short name prefix"
  type        = string
  default     = "tfstate"
}

variable "s3_bucket_name" {
  description = "Custom S3 bucket name (optional)"
  type        = string
  default     = null
}

variable "s3_expiration_days" {
  description = "Days after which objects expire"
  type        = number
  default     = 90
}

variable "block_public_access" {
  description = "Block all public access"
  type        = bool
  default     = true
}

variable "versioning_enabled" {
  description = "Enable versioning"
  type        = bool
  default     = true
}

variable "server_side_encryption" {
  description = "Enable SSE"
  type        = bool
  default     = true
}

variable "prevent_s3_bucket_destroy" {
  description = "Prevent accidental bucket deletion"
  type        = bool
  default     = false
}

variable "s3_force_destroy" {
  description = "Force destroy bucket (use with caution)"
  type        = bool
  default     = false
}
