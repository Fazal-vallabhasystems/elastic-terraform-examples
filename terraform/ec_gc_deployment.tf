# -------------------------------------------------------------
#  Deploy Elastic Cloud
# -------------------------------------------------------------
resource "ec_deployment" "elastic_gc_deployment" {
  name                    = var.elastic_gc_deployment_name
  region                  = var.elastic_gc_region
  version                 = var.elastic_version
  deployment_template_id  = var.elastic_gc_deployment_template_id
  elasticsearch {
	autoscale = "true"
  }
  kibana {}
  integrations_server {}
}

output "elastic_endpoint" {
  value = ec_deployment.elastic_gc_deployment.elasticsearch[0].https_endpoint
}

output "elastic_password" {
  value = ec_deployment.elastic_gc_deployment.elasticsearch_password
  sensitive=true
}

output "elastic_cloud_id" {
  value = ec_deployment.elastic_gc_deployment.elasticsearch[0].cloud_id
}

output "elastic_username" {
  value = ec_deployment.elastic_gc_deployment.elasticsearch_username
}

# -------------------------------------------------------------
#  Load Policy
# -------------------------------------------------------------

data "external" "elastic_create_gcp_policy" {
  query = {
    kibana_endpoint  = ec_deployment.elastic_gc_deployment.kibana[0].https_endpoint
    elastic_username  = ec_deployment.elastic_gc_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_gc_deployment.elasticsearch_password
    elastic_json_body = templatefile("../json_templates/default-policy.json", {"policy_name": "GCP"})
  }
  program = ["sh", "../scripts/kb_create_agent_policy.sh" ]
  depends_on = [ec_deployment.elastic_gc_deployment]
}

output "elastic_create_gcp_policy" {
  value = data.external.elastic_create_gcp_policy.result
  depends_on = [data.external.elastic_create_gcp_policy]
}

data "external" "elastic_add_gcp_integration" {
  query = {
    kibana_endpoint  = ec_deployment.elastic_gc_deployment.kibana[0].https_endpoint
    elastic_username  = ec_deployment.elastic_gc_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_gc_deployment.elasticsearch_password
    elastic_json_body = templatefile("../json_templates/gcp_integration.json", 
    {
    "policy_id": data.external.elastic_create_gcp_policy.result.id,
    "gcp_project": var.google_cloud_project,
    "gcp_credentials_json": jsonencode(file(var.google_cloud_service_account_path)),
    "audit_log_topic": var.google_pubsub_audit_topic,
    "firewall_log_topic": var.google_pubsub_firewall_topic,
    "vpcflow_log_topic": var.google_pubsub_vpcflow_topic,
    "dns_log_topic": var.google_pubsub_dns_topic,
    "lb_log_topic": var.google_pubsub_lb_topic     
    }
    )
  }
  program = ["sh", "../scripts/kb_add_integration_to_policy.sh" ]
  depends_on = [data.external.elastic_create_gcp_policy]
}

output "elastic_add_gcp_integration" {
  value = data.external.elastic_add_gcp_integration.result
  depends_on = [data.external.elastic_add_gcp_integration]
}