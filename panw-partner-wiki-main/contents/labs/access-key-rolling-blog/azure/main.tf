resource "azurerm_resource_group" "secrets_roller_rg" {
  name     = var.resource_group
  location = var.region
}

resource "azurerm_storage_account" "function_app_storage_account" {
  name                     = "pckeyrollingsa"
  resource_group_name      = azurerm_resource_group.secrets_roller_rg.name
  location                 = azurerm_resource_group.secrets_roller_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "function_app_service_plan" {
  name                = "prisma-cloud-key-rolling-service-plan"
  resource_group_name = azurerm_resource_group.secrets_roller_rg.name
  location            = azurerm_resource_group.secrets_roller_rg.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "function_app" {
  name                = "pc-key-rolling-function-app"
  resource_group_name = azurerm_resource_group.secrets_roller_rg.name
  location            = azurerm_resource_group.secrets_roller_rg.location

  storage_account_name       = azurerm_storage_account.function_app_storage_account.name
  storage_account_access_key = azurerm_storage_account.function_app_storage_account.primary_access_key
  service_plan_id            = azurerm_service_plan.function_app_service_plan.id
  zip_deploy_file                        = data.archive_file.python_function_package.output_path

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE       = 1
    #AzureWebJobsFeatureFlags       = "EnableWorkerIndexing"
        KEY_VAULT_NAME                             = "${var.key_vault_name}"
        SCM_DO_BUILD_DURING_DEPLOYMENT = true
    ENABLE_ORYX_BUILD              = true
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  site_config {
    application_stack {
        python_version = "3.9"
    }
        application_insights_connection_string = azurerm_application_insights.function_insights.connection_string  
    application_insights_key = azurerm_application_insights.function_insights.instrumentation_key 
    cors {
      allowed_origins = [
        "https://portal.azure.com",
      ]
      support_credentials = false
    }
  }
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "pckeyrolling-law"
  location            = azurerm_resource_group.secrets_roller_rg.location
  resource_group_name = azurerm_resource_group.secrets_roller_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "function_insights" {
  name                = "appinsights-event"
  location            = azurerm_resource_group.secrets_roller_rg.location
  resource_group_name = azurerm_resource_group.secrets_roller_rg.name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "other"
}

# this is a hack - need to get the python dependencies because we are 
# trying to deploy it all via terraform.  in reality, we should really 
# set up a CI/CD pipeline to deploy the Azure Funciton...but this is 
# just a demo enviornment so we won't worry about it for now
resource "terraform_data" "get_dependencies" {
  provisioner "local-exec" {
    command = "pip install --target=./resources/.python_packages/lib/site-packages -r ./resources/requirements.txt"
  }
}

data "archive_file" "python_function_package" {  
  type = "zip"  
  source_dir = "./resources/" 
  #output_path = "./archives/${sha1(join("", [for f in fileset("./resources/", "**") : filesha1("./resources/${f}")]))}-function.zip"
  output_path = "./archives/function-code.zip"
  
  depends_on = [
        terraform_data.get_dependencies
  ]
}

############################################
# UPDATE
# https://medium.com/@lupass93/event-driven-reactive-programming-and-serverless-solution-with-azure-event-grid-and-azure-function-a72b63862102
# https://github.com/Azure-Samples/azure-functions-event-grid-terraform/blob/main/infrastructure/terraform/main.tf
############################################
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "pc_access_keys" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.secrets_roller_rg.location
  resource_group_name         = azurerm_resource_group.secrets_roller_rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name = "standard"
}

resource "azurerm_key_vault_access_policy" "azure_function_principal" {
  key_vault_id = azurerm_key_vault.pc_access_keys.id
  object_id = azurerm_linux_function_app.function_app.identity.0.principal_id
  tenant_id = azurerm_linux_function_app.function_app.identity.0.tenant_id

  secret_permissions = [
    "Set", "Get", "List"
  ]
}

resource "azurerm_key_vault_access_policy" "terraform_deployment_principal" {
  key_vault_id = azurerm_key_vault.pc_access_keys.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Set", "Get", "List", "Delete", "Purge"
  ]
}

resource "azurerm_key_vault_secret" "service_account_access_key" {
  name         = "${var.secret_name}"
  value        = jsonencode({"PRISMA_CLOUD_USER"="${var.initial_access_key}","PRISMA_CLOUD_PASS"="${var.initial_secret_key}","PRISMA_CLOUD_CONSOLE_URL"="${var.prisma_cloud_console_url}"})
  key_vault_id = azurerm_key_vault.pc_access_keys.id
  
  # calculate the expiration_date using the rotation interval
  # terraform doesnt offer days as a timeadd, so convert to hours first
  expiration_date = timeadd(formatdate("YYYY-MM-01'T'00:00:00Z", timestamp()), "${var.rotation_interval * 24}h")
  
  tags = {
        ROTATE_ON_INITIAL = "true"
  }
  
  depends_on = [
        azurerm_key_vault_access_policy.terraform_deployment_principal,
        azurerm_key_vault_access_policy.azure_function_principal,
        azurerm_eventgrid_system_topic_event_subscription.eventgrid_subscription
  ]

}

resource "azurerm_storage_account" "key_rolling_events_storage" {
  name                     = "pckeyrollingevents"
  resource_group_name      = azurerm_resource_group.secrets_roller_rg.name
  location                 = azurerm_resource_group.secrets_roller_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_eventgrid_system_topic" "events_topic" {
  name                = "keyrolling-events-topic"
  resource_group_name = azurerm_resource_group.secrets_roller_rg.name
  location            = azurerm_resource_group.secrets_roller_rg.location

  #source_arm_resource_id = azurerm_storage_account.key_rolling_events_storage.id 
  source_arm_resource_id = azurerm_key_vault.pc_access_keys.id
  topic_type = "Microsoft.KeyVault.vaults"
}

resource "azurerm_eventgrid_system_topic_event_subscription" "eventgrid_subscription" {
  name                = "keyrollingeventsub"
  system_topic        = azurerm_eventgrid_system_topic.events_topic.name
  resource_group_name = azurerm_resource_group.secrets_roller_rg.name

  azure_function_endpoint {
    function_id = "${azurerm_linux_function_app.function_app.id}/functions/eventGridTrigger"
    max_events_per_batch              = 1
    preferred_batch_size_in_kilobytes = 64
  }
  
  included_event_types = [ 
        "Microsoft.KeyVault.SecretNearExpiry",
        "Microsoft.KeyVault.SecretNewVersionCreated"
  ]
  subject_filter {
    subject_begins_with = "${var.secret_name}"
        subject_ends_with = "${var.secret_name}"
        case_sensitive = false
  }
}
