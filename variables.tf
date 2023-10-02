variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "public_key_path" {
  description = "Local path to public SSH key. To generate the key pair use `ssh-keygen -t rsa -C admin -N '' -f id_rsa`  If you do not have a public key, run `ssh-keygen -f ~/.ssh/demo-key -t rsa -C admin`"
  type        = string
}

variable "mgmt_allow_ips" {
  description = "A list of IP addresses to be added to the management network's ingress firewall rule. The IP addresses will be able to access to the VM-Series management interface."
  type        = list(string)
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "zone" {
  description = "GCP Zone"
  type        = string
}

variable "prefix" {
  description = "Prefix to GCP resource names, an arbitrary string"
  default     = null
  type        = string
}

variable "vmseries_image" {
  description = "Name of the VM-Series image within the paloaltonetworksgcp-public project.  To list available images, run: `gcloud compute images list --project paloaltonetworksgcp-public --no-standard-images`. If you are using a custom image in a different project, please update `local.vmseries_iamge_url` in `main.tf`."
  default     = "vmseries-flex-bundle2-1022h2"
  type        = string
}