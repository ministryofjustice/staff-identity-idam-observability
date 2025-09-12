# Setting up a new environment

Some resources and settings are not controlled by Terraform. This is to reduce the required permission level the pipeline would need to run. When setting up a new environment, the following must be setup.

## Setup Resource Group

Manually create a new Resource Group using the following naming convention.

`rg-${var.department}-${var.team}-${var.project}`

## Setup storage account

Create a new Storage Account and container for holding the Terraform state file in. This should be called the following.

Storage Account Name: `stidamobservetfstate`
Container Name: `tfstate`

These values are referenced in the [terraform.tf](../../terraform/terraform.tf) file for the backend. As this part of the configuration cannot accept variables, this should always be the same on any environment you create.

## Setup Service Principle

In order for the pipeline to run, we will create a Service Principle with the appropriate persmissions to build Azure resources within our Resource Group.

### App Registration

Create a new App Registration using the following naming convention.

`${var.department}-${var.team}-${var.project}-pipeline`

For example: `eucs-idam-observability-pipeline`

In the Resource Group -> Access Control (IAM), give the pipeline the following Roles.

* Owner over this Resource Group
* Reader over the Subscription
* User Access Administrator over this Resource Group and Subscription

### Client Secret

Create a new client secret to be used for running the Terraform/Pipeline locally or in GitHub.

## Run Terraform

Run your Terraform to setup the resources in your Resource Group.

## Set Managed Identity permission

Go to Enterprise applications and find your App Registration. Assign the role Directory Reader to your Managed Identity to allow it to read all app registration details.

We set this manually rather than through code, meaning we do not give the pipeline a higher set of permissions.

## MI Roles

The Managed Identity will require specific roles to be able to query data and make changes in the tenant. Go to Entra -> Roles & Administrators and assign the relevant permissions to enable it to work.

This will be required if when you run a job it returns an error saying the MI does not have permission to xxx.Read.All for example.

## Graph Package Dependencies

The code in this repository requires version 2.5.0 of the Graph API. After this version, Connect-MgGraph fails to authenticate due to changes in the API. You should use the steps below when adding new dependecies rather than the built in Module Catalogue option.

If you need to add a new package, follow these steps

### Download to your machine the Graph library

`Save-Module -Name Microsoft.Graph.Groups -RequiredVersion 2.25.0 -Path "C:\psmodules"`

### Zip Folder

Go to the directory you downloaded it to, right click the folder and Compress/Add to Zip file

### Add module

Go to the Modules section in the Automation Account, add new module and upload the Zip file choosing PowerShell version 7.2
