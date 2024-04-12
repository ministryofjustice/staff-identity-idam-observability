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

In the Resource Group -> Access Control (IAM), give the `` the following Roles.

* Owner over this Resource Group
* Reader over the Subscription
* User Access Administrator over this Resource Group and Subscription

## Run Terraform

Run your Terraform to setup the resources in your Resource Group.

## Set Managed Identity permission

Go to Enterprise applications and find your App Registration. Assign the role Directory Reader to your Managed Identity to allow it to read all app registration details. 
