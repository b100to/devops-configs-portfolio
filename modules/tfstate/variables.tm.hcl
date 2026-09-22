generate_hcl "_terramate_generated_variables.tf" {
  content {
    variable "acl" {
      description = "The canned ACL to apply. Defaults to private."
      type        = string
      default     = "private"
    }

    variable "control_object_ownership" {
      description = "Control object ownership. Defaults to true."
      type        = bool
      default     = "true"
    }

    variable "object_ownership" {
      description = "Object ownership. Defaults to ObjectWriter."
      type        = string
      default     = "ObjectWriter"
    }

    variable "versioning" {
      description = "Versioning configuration for the bucket."
      type = object({
        enabled = optional(bool)
      })
      default = {
        enabled = true
      }
    }

  }
}
