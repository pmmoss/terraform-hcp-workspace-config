terraform {
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.58.0"  # Use latest compatible version
    }
  }
  required_version = ">= 1.6.0"
}

provider "tfe" {
}

# Data source for the organization (assumes it exists)
data "tfe_organization" "org" {
  name = var.organization_name
}

# Create teams dynamically
resource "tfe_team" "team" {
  for_each = var.teams_config

  name         = each.key
  organization = data.tfe_organization.org.name
  visibility   = each.value.visibility

  dynamic "organization_access" {
    for_each = each.value.organization_access == null ? [] : [each.value.organization_access]
    content {
      manage_projects    = try(organization_access.value.manage_projects, null)
      manage_workspaces  = try(organization_access.value.manage_workspaces, null)
      manage_teams       = try(organization_access.value.manage_teams, null)
      read_projects      = try(organization_access.value.read_projects, null)
      read_workspaces    = try(organization_access.value.read_workspaces, null)
    }
  }
}

locals {
  projects_from_config = var.projects_config
}

# Create projects (from config plus legacy fixed ones if config is empty)
resource "tfe_project" "project" {
  for_each = local.projects_from_config

  name         = each.key
  organization = data.tfe_organization.org.name
}

# Assign team access to projects based on config.team_access
locals {
  project_team_access_entries = merge([
    for project_name, project in local.projects_from_config : (
      length(try(project.team_access, {})) > 0
      ? [for team_name, tac in project.team_access : {
          key = "${project_name}:${team_name}"
          value = { project = project_name, team_name = team_name, access = tac.access }
        }]
      : []
    )
  ]...)
}

resource "tfe_team_project_access" "project_team_access" {
  for_each = { for item in local.project_team_access_entries : item.key => item.value }

  team_id   = tfe_team.team[each.value.team_name].id
  project_id = tfe_project.project[each.value.project].id
  access     = each.value.access
}

# Create workspaces from config
locals {
  workspace_matrix = flatten([
    for project_name, project in local.projects_from_config : [
      for ws_name, ws in project.workspaces : (
        length(ws.apps) > 0 ? [
          for app in ws.apps : [
            for env in var.environments : {
              name        = replace(ws_name, "${app}", app)
              project     = project_name
              environment = env
            }
          ]
        ] : [
          for env in (ws.per_environment ? var.environments : ["-"]) : {
            name        = ws.per_environment ? "${ws_name}-${env}" : ws_name
            project     = project_name
            environment = env
          }
        ]
      )
    ]
  ])

  workspace_map = {
    for item in local.workspace_matrix : "${item.project}:${item.name}" => item
  }
}

resource "tfe_workspace" "ws" {
  for_each = local.workspace_map

  name         = each.value.name
  organization = data.tfe_organization.org.name
  project_id   = tfe_project.project[each.value.project].id
  allow_destroy_plan = each.value.environment != "prod" ? true : false
}

locals {
  workspace_team_access_list = flatten([
    for project_name, project in var.projects_config : flatten([
      for ws_name, ws in project.workspaces : (
        length(try(ws.team_access, {})) > 0 ? flatten([
          for team_name, team_cfg in ws.team_access : (
            length(try(ws.apps, [])) > 0
            ? flatten([
                for app in ws.apps : [
                  for env in (try(ws.per_environment, true) ? var.environments : ["-"]) : {
                    key   = try(ws.per_environment, true) ? "${project_name}:${replace(ws_name, "${app}", app)}-${env}:${team_name}" : "${project_name}:${replace(ws_name, "${app}", app)}:${team_name}"
                    value = {
                      workspace_key = try(ws.per_environment, true) ? "${project_name}:${replace(ws_name, "${app}", app)}-${env}" : "${project_name}:${replace(ws_name, "${app}", app)}"
                      team_name     = team_name
                      access        = team_cfg.access
                      permissions   = try(team_cfg.permissions, null)
                    }
                  }
                ]
              ])
            : [
                for env in (try(ws.per_environment, true) ? var.environments : ["-"]) : {
                  key   = try(ws.per_environment, true) ? "${project_name}:${ws_name}-${env}:${team_name}" : "${project_name}:${ws_name}:${team_name}"
                  value = {
                    workspace_key = try(ws.per_environment, true) ? "${project_name}:${ws_name}-${env}" : "${project_name}:${ws_name}"
                    team_name     = team_name
                    access        = team_cfg.access
                    permissions   = try(team_cfg.permissions, null)
                  }
                }
              ]
          )
        ]) : []
      )
    ])
  ])

  workspace_team_access_entries = {
    for item in local.workspace_team_access_list : item.key => item.value
  }
}

resource "tfe_team_access" "ws_team_access_expanded" {
  for_each = local.workspace_team_access_entries

  team_id = tfe_team.team[each.value.team_name].id

  workspace_id = tfe_workspace.ws[each.value.workspace_key].id
  access       = each.value.access

  dynamic "permissions" {
    for_each = each.value.permissions == null ? [] : [each.value.permissions]
    content {
      runs              = try(permissions.value.runs, null)
      run_tasks         = try(permissions.value.run_tasks, null)
      sentinel_mocks    = try(permissions.value.sentinel_mocks, null)
      state_versions    = try(permissions.value.state_versions, null)
      variables         = try(permissions.value.variables, null)
      workspace_locking = try(permissions.value.workspace_locking, null)
    }
  }
}