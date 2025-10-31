output "workspace_ids" {
  value       = { for k, v in tfe_workspace.ws : k => v.id }
  description = "Map of workspace composite keys to IDs"
}

output "team_ids" {
  value       = { for k, v in tfe_team.team : k => v.id }
  description = "Map of team names to IDs"
}

output "project_ids" {
  value       = { for k, v in tfe_project.project : k => v.id }
  description = "Map of project names to IDs"
}