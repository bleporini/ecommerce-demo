variable "confluent_cloud_api_key" {
  description = "Cloud API key"
  type        = string
  default     = ""
}

variable "confluent_cloud_api_secret" {
  description = "Cloud API secret"
  type        = string
  default     = ""
}

variable "region" {
  description = "Cloud region"
  type        = string
  default     = "asia-south1"
}

variable "sr_region" {
  description = "Cloud region"
  type        = string
  default     = "sgreg-6"
}

variable "cloud" {
  description = "Cloud provider"
  type        = string
  default     = "GCP"
}

variable "db_hostname" {
  type        = string
}


variable "db_password" {
  type        = string
}

variable "mongodbatlas_public_key" {
  type        = string
}

variable "mongodbatlas_private_key" {
  type        = string
}

variable "mongodbatlas_project_id" {
  type        = string
}

variable "mongodbatlas_provider" {
  type        = string
  default     = "GCP"
}

variable "mongodbatlas_region" {
  type        = string
  default     = "ASIA_SOUTH_1"
}


variable "mongodbatlas_password" {
  type        = string
}
