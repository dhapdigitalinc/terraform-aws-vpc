variable "name" {
  description = "Name to be used on all the resources as identifier"
  default     = ""
}

variable "cidr" {
  description = "The CIDR block for the VPC"
  default     = ""
}

variable "adm_vpc_name" {
  default = ""
}

variable "instance_tenancy" {
  description = "A tenancy option for instances launched into the VPC"
  default     = "default"
}

variable "public_subnet_count" {
  description = "Number of public subnets in the VPC"
  default     = 0
}

variable "private_subnet_count" {
  description = "Number of private subnets in the VPC"
  default     = 0
}

variable "database_subnet_count" {
  description = "Number of database subnets in the VPC"
  default     = 0
}

variable "redshift_subnet_count" {
  description = "Number of RedShift subnets in the VPC"
  default     = 0
}

variable "elasticache_subnet_count" {
  description = "Number of database subnets in the VPC"
  default     = 0
}

variable "azs" {
  type        = "list"
  description = "A list of Availability zones in the region"
  default     = []
}

variable "enable_dns_hostnames" {
  description = "should be true if you want to use private DNS within the VPC"
  default     = false
}

variable "enable_dns_support" {
  description = "should be true if you want to use private DNS within the VPC"
  default     = false
}

variable "enable_nat_gateway" {
  description = "should be true if you want to provision NAT Gateways for each of your private networks"
  default     = false
}

variable "single_nat_gateway" {
  description = "should be true if you want to provision a single shared NAT Gateway across all of your private networks"
  default     = false
}

variable "enable_dynamodb_endpoint" {
  description = "should be true if you want to provision an DynamoDB endpoint to the VPC"
  default     = true
}

variable "enable_s3_endpoint" {
  description = "should be true if you want to provision an S3 endpoint to the VPC"
  default     = true
}

variable "map_public_ip_on_launch" {
  description = "should be false if you do not want to auto-assign public IP on launch"
  default     = true
}

variable "private_propagating_vgws" {
  type        = "list"
  description = "A list of VGWs the private route table should propagate."
  default     = []
}

variable "public_propagating_vgws" {
  type        = "list"
  description = "A list of VGWs the public route table should propagate."
  default     = []
}

variable "tags" {
  type        = "map"
  description = "A map of tags to add to all resources"
  default     = {}
}

variable "vpc_tags" {
  type        = "map"
  description = "Additional tags for the VPC"
  default     = {}
}

variable "public_subnet_tags" {
  type        = "map"
  description = "Additional tags for the public subnets"
  default     = {}
}

variable "private_subnet_tags" {
  type        = "map"
  description = "Additional tags for the private subnets"
  default     = {}
}

variable "public_route_table_tags" {
  type        = "map"
  description = "Additional tags for the public route tables"
  default     = {}
}

variable "private_route_table_tags" {
  type        = "map"
  description = "Additional tags for the private route tables"
  default     = {}
}

variable "database_subnet_tags" {
  type        = "map"
  description = "Additional tags for the database subnets"
  default     = {}
}

variable "redshift_subnet_tags" {
  type        = "map"
  description = "Additional tags for the redshift subnets"
  default     = {}
}

variable "elasticache_subnet_tags" {
  type        = "map"
  description = "Additional tags for the elasticache subnets"
  default     = {}
}

variable "dhcp_options_tags" {
  type        = "map"
  description = "Additional tags for the DHCP option set"
  default     = {}
}

variable "enable_dhcp_options" {
  description = "Should be true if you want to specify a DHCP options set with a custom domain name, DNS servers, NTP servers, netbios servers, and/or netbios server type"
  default     = true
}

variable "dhcp_options_domain_name" {
  description = "Specifies DNS name for DHCP options set"
  default     = "watchwith.local"
}

variable "dhcp_options_domain_name_servers" {
  description = "Specify a list of DNS server addresses for DHCP options set, default to AWS provided"
  type        = "list"
  default     = ["AmazonProvidedDNS"]
}

variable "dhcp_options_ntp_servers" {
  description = "Specify a list of NTP servers for DHCP options set"
  type        = "list"
  default     = []
}

variable "dhcp_options_netbios_name_servers" {
  description = "Specify a list of netbios servers for DHCP options set"
  type        = "list"
  default     = []
}

variable "dhcp_options_netbios_node_type" {
  description = "Specify netbios node_type for DHCP options set"
  default     = ""
}

