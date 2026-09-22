// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "acl" {
  default     = "private"
  description = "The canned ACL to apply. Defaults to private."
  type        = string
}
variable "control_object_ownership" {
  default     = "true"
  description = "Control object ownership. Defaults to true."
  type        = bool
}
variable "object_ownership" {
  default     = "ObjectWriter"
  description = "Object ownership. Defaults to ObjectWriter."
  type        = string
}
variable "versioning" {
  default = {
    enabled = true
  }
  description = "Versioning configuration for the bucket."
  type = object({
    enabled = optional(bool)
  })
}
