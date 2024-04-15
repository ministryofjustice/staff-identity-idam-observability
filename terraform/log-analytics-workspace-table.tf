resource "azapi_resource" "workspaces_table" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2021-12-01-preview"
  name      = "${var.department}_${var.team}_${var.project}_logs_CL"
  parent_id = azurerm_log_analytics_workspace.log_analytics_workspace.id

  body = jsonencode({
    properties = {
      plan = "Analytics",
      schema = {
        name = "${var.department}_${var.team}_${var.project}_logs_CL",
        columns = [
          {
            name = "displayname",
            type = "string"
          },
          {
            name = "objectid",
            type = "string"
          },
          {
            name = "applicationid",
            type = "string"
          },
          {
            name = "keyid",
            type = "string"
          },
          {
            name = "eventtype",
            type = "string"
          },
          {
            name = "startdate",
            type = "dateTime"
          },
          {
            name = "enddate",
            type = "dateTime"
          },
          {
            name = "status",
            type = "string"
          },
          {
            name = "TimeGenerated",
            type = "dateTime"
          },
          {
            name = "daystoexpiration",
            type = "int"
          }
        ]
      }
    }
  })
  response_export_values = ["*"]

  depends_on = [
    azurerm_log_analytics_workspace.log_analytics_workspace
  ]
}
