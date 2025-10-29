output "workspace_ids" {
  value = merge(
    { for k, v in tfe_workspace.revms : k => v.id },
    { for k, v in tfe_workspace.evo_taskers_sub_apps : k => v.id },
    { for k, v in tfe_workspace.common : k => v.id },
    { for k, v in tfe_workspace.network : k => v.id },
    { for k, v in tfe_workspace.evo_taskers_common : k => v.id }
  )
  description = "Map of workspace names to IDs"
}

output "team_ids" {
  value = { for k, v in tfe_team.team : k => v.id }
  description = "Map of team names to IDs"
}

output "project_ids" {
  value = {
    infrastructure = tfe_project.infrastructure.id
    revms         = tfe_project.revms.id
    evo_taskers   = tfe_project.evo_taskers.id
  }
  description = "Map of project names to IDs"
}