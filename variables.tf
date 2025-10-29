
variable "organization_name" {
  type        = string
  description = "Name of the HCP Terraform organization"
  default     = "my-org"
}

variable "environments" {
  type        = list(string)
  description = "List of environments (e.g., ['dev', 'prod'])"
  default     = ["dev", "prod"]
}

variable "evo_taskers_sub_apps" {
  type        = list(string)
  description = "List of sub-apps for evo-taskers"
  default     = ["sub1", "sub2"]
}

# Flexible configuration to define projects, workspaces, and team access.
# Example shape:
# projects_config = {
#   "infrastructure" = {
#     workspaces = {
#       common  = { per_environment = true }
#       network = { per_environment = true, team_access = { network = { access = "custom", permissions = { runs = "apply", variables = "write" } } } }
#     }
#     team_access = { infrastructure = { access = "admin" } }
#   }
#   "revms" = {
#     workspaces = { revms = { per_environment = true } }
#     team_access = { revms_app = { access = "write" } }
#   }
#   "evo-taskers" = {
#     workspaces = {
#       "evo-taskers-common" = { per_environment = true }
#       # Pattern workspaces generated for each sub app when pattern contains ${app}
#       "evo-taskers-${app}" = { per_environment = true, apps = var.evo_taskers_sub_apps }
#     }
#     team_access = { evo_taskers_app = { access = "write" } }
#   }
# }
variable "projects_config" {
  description = "Declarative configuration for projects, workspaces, and team access"
  type = map(object({
    workspaces = map(object({
      per_environment = optional(bool, true)
      apps            = optional(list(string), [])
      team_access     = optional(map(object({
        access = string
        permissions = optional(object({
          runs              = optional(string)
          run_tasks         = optional(bool)
          sentinel_mocks    = optional(string)
          state_versions    = optional(string)
          variables         = optional(string)
          workspace_locking = optional(bool)
        }))
      })), {})
    }))
    team_access = optional(map(object({ access = string })), {})
  }))
  default = {}
}

# Declarative team definitions (name => config)
# Example:
# teams_config = {
#   application-admin = {
#     visibility = "organization"
#     organization_access = {
#       manage_projects   = true
#       manage_workspaces = true
#       manage_teams      = true
#       read_projects     = true
#       read_workspaces   = true
#     }
#   }
#   network = { visibility = "organization" }
# }
variable "teams_config" {
  description = "Teams to create and their optional org-level permissions"
  type = map(object({
    visibility          = optional(string, "organization")
    organization_access = optional(object({
      manage_projects    = optional(bool)
      manage_workspaces  = optional(bool)
      manage_teams       = optional(bool)
      read_projects      = optional(bool)
      read_workspaces    = optional(bool)
    }))
  }))
  default = {}
}