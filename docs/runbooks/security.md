# Security and Permissions Overview

## Pipeline and Managed Identity Permissions

The following details the required permissions for the pipeline and Managed Identity to run successfully.

The Pipeline will set the `Monitoring Metrics Publisher` and `Reader` permissions for the Managed Identity using the pipeline permissions set below.

Because we want to keep the pipeline permissions to a minimum, we must set the additional permission `Directory Reader` manually after the Terraform has built the infrastructure. This is reflected in the table below.

| Resource Name                    | Level                         | Permission                   | Description                                                                                  |
|----------------------------------|-------------------------------|------------------------------|----------------------------------------------------------------------------------------------|
| eucs-idam-observability-pipeline | Resource Group                | Owner                        | Allows the pipeline to build the Azure resources within this resource group.                 |
| eucs-idam-observability-pipeline | Subscription                  | Reader                       | Allows the reading of permissions that can be set for the Managed Identity to be created.    |
| eucs-idam-observability-pipeline | Resource Group                | User Access Administrator    | Allow the setting of the created Managed Identity permissions to Azure resources.            |
| eucs-idam-observability-pipeline | Subscription                  | User Access Administrator    | Allow the setting of the created Managed Identity permissions to Azure resources.            |
| mi-eucs-idam-observability       | Subscription                  | Reader                       | Allows the PowerShell script to read details from the App Registration queries.              |
| mi-eucs-idam-observability       | Data Collection Rule Resource | Monitoring Metrics Publisher | Allows the PowerShell script to write records to Log Analytics via the Data Collection Rule. |
| mi-eucs-idam-observability       | Subscription                  | Directory Reader             | Allows the PowerShell script to read all App Registration details.                           |