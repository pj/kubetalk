variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
}

variable "state_bucket" {
  description = "Name of the S3 bucket used for Terraform state"
  type        = string
  default     = "kubetalk-terraform-state-11fa7ba563004e35b3292de137f9c43e"
} 