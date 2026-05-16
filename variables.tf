variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-west-2"
}

variable "dr_region" {
  description = "Disaster Recovery AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "automation_region" {
  description = "AWS region for automation resources (CloudWatch, SNS, Lambda)"
  type        = string
  default     = "ca-central-1"
}

variable "hosted_zone_name" {
  description = "Existing public Route 53 hosted zone name"
  type        = string
}

variable "record_name" {
  description = "DNS record managed by this DR stack. Use a dedicated subdomain to avoid impacting an existing website."
  type        = string
}

variable "key_name" {
  description = "Optional default EC2 key pair name for SSH access in both application regions"
  type        = string
  default     = null
}

variable "primary_key_name" {
  description = "Optional EC2 key pair name for the primary region. Defaults to key_name."
  type        = string
  default     = null
}

variable "dr_key_name" {
  description = "Optional EC2 key pair name for the DR region. Defaults to key_name."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
}

variable "notification_email" {
  description = "Optional email address to subscribe to failover completion notifications"
  type        = string
  default     = null
}
