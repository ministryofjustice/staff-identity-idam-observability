# Setting up a new environment

This guide gives you a step by step process for setting an environment from scratch.

## 1. Setup a Resource Group

1. Go to `Resource Group` within the Azure portal.
2. Click `Create`.
3. Enter a `Resource group` name.
4. Select `(Europe) UK South` from the `Region` drop down.
5. Click `Review + create` and complete the creation of the Resource group.

## 2. Setup a Managed Identity

1. Go to `Managed Identities` within the Azure portal.
2. Click `Create`.
3. Select your resource group from the `Resource group` drop down.
4. Select `(Europe) UK South` from the `Region` drop down.
5. Enter a well named managed identity in the `Name` field. E.g. `idam-expiration-monitoring-mi`
6. Click `Review + create` and complete the creation of the Managed Identity.

## 3. Automation Account

### Creating an Account

1. Go to `Automation Accounts` within the Azure portal.
2. Click `Create`.
3. Select your resource group from the `Resource group` drop down.
4. Select `UK South` from the `Region` drop down.
5. Enter value in the `Automation account name` field. E.g. `idam-monitoring-automation`
6. Select the `Advanced` tab and choose `User assigned`.
7. Select your Managed Identity created in [Step 2](#2-setup-a-managed-identity).
8. Click `Review + create` and complete the creation of the Automation Account.

### Create a Runbook

1. Go to your new Automation Account.
2. Under `Process Automation` select `Runbooks`.
3. Select `Import a runbook`.
4. Upload the [file process-app-registration-secrets-certifiates.ps1 located in /script/ps](../../scripts/ps/process-app-registration-secrets-certifiates.ps1)
5. Modify the `Name` value if required.
6. Set `Runbook type` to `PowerShell` and `Runtime version` to `7.2 (recommended)`.
7. Click `Import`.
8. Click `Publish`.

## 4. Create a Data collection endpoint

1. Go to `Data collection endpoints` within the Azure portal.
2. Click `Create`.
3. Select your resource group from the `Resource group` drop down.
4. Select `UK South` from the `Region` drop down.
5. Enter value in the `Endpoint Name` field. E.g. `app-registration-expiration-endpoint`

## 5. Data collection rule

### Creating a Data collection rule

1. Go to `Data collection rules` within the Azure portal.
2. Click `Create`.
3. Select your resource group from the `Resource group` drop down.
4. Select `UK South` from the `Region` drop down.
4. Select `Platform Type` as `Linux` drop down.
5. Select your `Data Collection Endpoint` created in [Step 4](#4-create-a-data-collection-endpoint).
6. Click `Review + create` and complete the creation of the Data collection rule.

### Set Permissions

1. Select your new `Data collection rule`.
2. Click `Access control (IAM)`.
3. Click `Add` and `Add role assignment`.
4. In the `Role` tab select `Monitoring Metrics Publisher`.
5. In the `Members` tab choose `Managed identity` for `Assign access to`.
6. Click `Select members`.
7. In `Managed identity` select `User-assigned managed identity`, select your managed identity and click `Select`.
6. Click `Review + assign` and complete the creation of the role assignment.

## 6. Log Analytics workspace

### Creating a workspace

1. Go to `Log Analytics workspace` within the Azure portal.
2. Click `Create`.
3. Select your resource group from the `Resource group` drop down.
4. Select `UK South` from the `Region` drop down.
5. Enter value in the `Name` field. E.g. `azure-secret-certificate-notification-logs`
6. Click `Review + create` and complete the creation of the Automation Account.

### Creating a table

1. Select your new `Log Analytics workspace`.
2. Go to `Settings` -> `Tables`.
3. Click `Create` and select `New custom log (DCR-based)`.
4. Populate `Table name` ensuring it ends with `_CL`. You must end your table name with `_CL` for Azure to understand it is a Custom Log.
5. Set the `Data collection rule` to your new Data Collection Rule in [Step 5](#5-data-collection-rule).
6. Click `Next`.
7. Click `Upload sample file`.
8. Upload the file `dcr-secret-certificate-notification-logs.json` in [/scripts/schemas](../../scripts/schemas/).
9. Click `Next`.
10. Review and Save to complete the creation of your table.

## 7. Set Managed Identity Role

1. Go to `Microsoft Entra ID` within the Azure portal.
2. Select `Roles and administrators`.
3. Select `Global Reader`.
4. Click `Add assignments`.
5. Assign the Managed Identity created in [Step 2](#2-setup-a-managed-identity) as a `Service principle`

## 8. Configure Automation

### Configure a schedule in the Automation Account

1. Go to `Automation Accounts` within the Azure portal.
2. Select your new Automation Account.
3. Go to `Schedules`.
4. Click `Add a schedule`.
5. Click `Link a schedule to your runbook`.
6. Click `Add a schedule` and complete the form defining your occurance requirements.
7. Click on `Configure parameters and run settings`.
8. Fill out the following details and click `OK`.
    - **MICLIENTID**: Your Managed Identity Client ID.
    - **DCRIMMUTABLEID**: Get from Data Collection rule -> View Json and find the value in properties/immutableId - starts with `dcr-`.
    - **LOGTABLENAME**: The name of your Custom Log table setup in [Step 6](#6-log-analytics-workspace) that ends in `_CL`.
    - **DceUri**: Go to your Data collection endpoint -> Overview -> take the value `Logs Ingestion`.
9. Click `OK`.

## 8. Create Workbook

1. Go to `Azure Workbooks` within the Azure portal.
2. Click `New`.
3. Click the `</>` button.
4. For `Template Type` choose `Gallery Template`.
5. Copy and paste the contents of the file [azure-secret-certificate-notification-logs.json](../../scripts/workbooks/azure-secret-certificate-notification-logs.json).
6. Click `Apply`.
7. Save your changes.

Once the automation script has run for the first time, you will be able to open the Workbook to see the appropriate data.
