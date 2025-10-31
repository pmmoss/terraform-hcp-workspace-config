
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

# Control whether this module creates projects or references existing ones
variable "create_projects" {
  type        = bool
  description = "If true, create TFE projects. If false, look up existing projects by name."
  default     = true
}

# Control whether this module creates teams or references existing ones
variable "create_teams" {
  type        = bool
  description = "If true, create TFE teams. If false, look up existing teams by name."
  default     = true
}

#
variable "projects_config" {
  description = "Declarative configuration for projects, workspaces, and team access"
  type = map(object({
    workspaces = map(object({
      per_environment = optional(bool, true)
      apps            = optional(list(string), [])
      environments    = optional(list(string), null)
      vcs_repo        = optional(object({
        identifier      = string       # e.g. "github-org/repo"
        oauth_token_id  = string       # TFE OAuth token ID
        branch          = optional(string, null)
        ingress_submodules = optional(bool, null)
      }), null)
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

#
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