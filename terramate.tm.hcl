terramate {
  required_version = "~> 0.14.0"

  config {
    experiments = [
      "outputs-sharing"
    ]
    cloud {
      targets {
        enabled = true
      }
      organization = "acme-devops"
      location     = "us"
    }
    git {
      default_remote    = "origin"
      default_branch    = "main"
      check_untracked   = false
      check_uncommitted = false
    }
    run {
      env {
        TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE = "true"
      }
    }
  }
}

# create the default sharing_backend
sharing_backend "default" {
  type     = terraform
  filename = "_generated_sharing_backend.tf"
  command  = ["terraform", "output", "-json"]
}