terraform {
  required_version = ">= 0.10.3" # introduction of Local Values configuration language feature
}

locals {
  max_subnet_length = "${max(length(var.private_subnets), length(var.elasticache_subnets), length(var.database_subnets), length(var.redshift_subnets))}"
}

######
# VPC
######
resource "aws_vpc" "this" {
  count = "${var.create_vpc ? 1 : 0}"

  cidr_block           = "${var.cidr}"
  instance_tenancy     = "${var.instance_tenancy}"
  enable_dns_hostnames = "${var.enable_dns_hostnames}"
  enable_dns_support   = "${var.enable_dns_support}"

  tags = "${merge(var.tags, var.vpc_tags, map("Name", format("%s", var.name)))}"
}

###################
# DHCP Options Set
###################
resource "aws_vpc_dhcp_options" "this" {
  count = "${var.create_vpc && var.enable_dhcp_options ? 1 : 0}"

  domain_name          = "${var.dhcp_options_domain_name}"
  domain_name_servers  = "${var.dhcp_options_domain_name_servers}"
  ntp_servers          = "${var.dhcp_options_ntp_servers}"
  netbios_name_servers = "${var.dhcp_options_netbios_name_servers}"
  netbios_node_type    = "${var.dhcp_options_netbios_node_type}"

  tags = "${merge(var.tags, var.dhcp_options_tags, map("Name", format("%s", var.name)))}"
}

###############################
# DHCP Options Set Association
###############################
resource "aws_vpc_dhcp_options_association" "this" {
  count = "${var.create_vpc && var.enable_dhcp_options ? 1 : 0}"

  vpc_id          = "${aws_vpc.this.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.this.id}"
}

###################
# Internet Gateway
###################
resource "aws_internet_gateway" "this" {
  count = "${var.create_vpc && length(var.public_subnets) > 0 ? 1 : 0}"

  vpc_id = "${aws_vpc.this.id}"

  tags = "${merge(var.tags, map("Name", format("%s", var.name)))}"
}

################
# Publiс routes
################
resource "aws_route_table" "public" {
  count = "${var.create_vpc && length(var.public_subnets) > 0 ? 1 : 0}"

  vpc_id           = "${aws_vpc.this.id}"
  propagating_vgws = ["${var.public_propagating_vgws}"]

  tags = "${merge(var.tags, var.public_route_table_tags, map("Name", format("%s-public", var.name)))}"
}

resource "aws_route" "public_internet_gateway" {
  count = "${var.create_vpc && length(var.public_subnets) > 0 ? 1 : 0}"

  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.this.id}"
}

# resource "aws_route" "ipv6_public_internet_gateway" {
#   count                       = "${var.public_subnet_count > 0 ? 1 : 0}"

#   route_table_id              = "${aws_route_table.public.id}"
#   destination_ipv6_cidr_block = "::/0"
#   gateway_id                  = "${aws_internet_gateway.this.id}"
# }

#################
# Private routes
# There are so many routing tables as the largest amount of subnets of each type (really?)
#################
resource "aws_route_table" "private" {
  count = "${var.create_vpc && local.max_subnet_length > 0 ? local.max_subnet_length : 0}"

  vpc_id           = "${aws_vpc.this.id}"
  propagating_vgws = ["${var.private_propagating_vgws}"]

  tags = "${merge(var.tags, var.private_route_table_tags, map("Name", format("%s-private-%s", var.name, element(var.azs, count.index))))}"

  lifecycle {
    # When attaching VPN gateways it is common to define aws_vpn_gateway_route_propagation
    # resources that manipulate the attributes of the routing table (typically for the private subnets)
    ignore_changes = ["propagating_vgws"]
  }
}

################
# Public subnet
################
resource "aws_subnet" "public" {
  count = "${var.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0}"

  vpc_id                  = "${aws_vpc.this.id}"
  cidr_block              = "${var.public_subnets[count.index]}"
  availability_zone       = "${element(var.azs, count.index)}"
  map_public_ip_on_launch = "${var.map_public_ip_on_launch}"

  # assign_ipv6_address_on_creation = true


  # ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.this.ipv6_cidr_block,8,count.index+1)}"

  tags = "${merge(var.tags, var.public_subnet_tags, map("Name", format("%s-public-%s", var.name, element(var.azs, count.index))))}"
}

#################
# Private subnet
#################
resource "aws_subnet" "private" {
  count = "${var.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0}"

  vpc_id            = "${aws_vpc.this.id}"
  cidr_block        = "${cidrsubnet(aws_vpc.this.cidr_block,8,count.index+11)}"
  availability_zone = "${element(var.azs, count.index)}"

  # assign_ipv6_address_on_creation = true


  # ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.this.ipv6_cidr_block,8,count.index+11)}"

  tags = "${merge(var.tags, var.private_subnet_tags, map("Name", format("%s-private-%s", var.name, element(var.azs, count.index))))}"
}

resource "aws_route" "private_nat_gateway" {
  count = "${var.enable_nat_gateway == "true" ? var.private_subnet_count : 0}"

  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.this.*.id, count.index)}"
}

#resource "aws_route" "private_egress_only_gateway" {
#  count                       = "${var.enable_nat_gateway == "true" ? var.private_subnet_count : 0}"
#  route_table_id              = "${element(aws_route_table.private.*.id, count.index)}"
#  destination_ipv6_cidr_block = "::/0"
#  egress_only_gateway_id      = "${element(aws_egress_only_internet_gateway.eigw.*.id, count.index)}"
#}

##################
# Database subnet
##################
resource "aws_subnet" "database" {
  count = "${var.create_vpc && length(var.database_subnets) > 0 ? length(var.database_subnets) : 0}"

  vpc_id            = "${aws_vpc.this.id}"
  cidr_block        = "${var.database_subnets[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"

#  assign_ipv6_address_on_creation = true
#  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.this.ipv6_cidr_block,8,count.index+21)}"

  tags = "${merge(var.tags, var.database_subnet_tags, map("Name", format("%s-db-%s", var.name, element(var.azs, count.index))))}"
}

resource "aws_db_subnet_group" "database" {
  count = "${var.create_vpc && length(var.database_subnets) > 0 && var.create_database_subnet_group ? 1 : 0}"

  name        = "${lower(var.name)}"
  description = "Database subnet group for ${var.name}"
  subnet_ids  = ["${aws_subnet.database.*.id}"]

  tags = "${merge(var.tags, map("Name", format("%s", var.name)))}"
}

##################
# Redshift subnet
##################
resource "aws_subnet" "redshift" {
  count = "${var.create_vpc && length(var.redshift_subnets) > 0 ? length(var.redshift_subnets) : 0}"

  vpc_id                          = "${aws_vpc.this.id}"
  cidr_block                      = "${cidrsubnet(aws_vpc.this.cidr_block,8,count.index+31)}"
  availability_zone               = "${element(var.azs, count.index)}"
#  assign_ipv6_address_on_creation = true
#  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.this.ipv6_cidr_block,8,count.index+31)}"

  tags = "${merge(var.tags, var.redshift_subnet_tags, map("Name", format("%s-redshift-%s", var.name, element(var.azs, count.index))))}"
}

resource "aws_redshift_subnet_group" "redshift" {
  count = "${var.create_vpc && length(var.redshift_subnets) > 0 ? 1 : 0}"

  name        = "${var.name}"
  description = "Redshift subnet group for ${var.name}"
  subnet_ids  = ["${aws_subnet.redshift.*.id}"]

  tags = "${merge(var.tags, map("Name", format("%s", var.name)))}"
}

#####################
# ElastiCache subnet
#####################
resource "aws_subnet" "elasticache" {
  count = "${var.create_vpc && length(var.elasticache_subnets) > 0 ? length(var.elasticache_subnets) : 0}"

  vpc_id                          = "${aws_vpc.this.id}"
  cidr_block                      = "${cidrsubnet(aws_vpc.this.cidr_block,8,count.index+41)}"
  availability_zone               = "${element(var.azs, count.index)}"
#  assign_ipv6_address_on_creation = true
#  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.this.ipv6_cidr_block,8,count.index+41)}"

  tags = "${merge(var.tags, var.elasticache_subnet_tags, map("Name", format("%s-elasticache-%s", var.name, element(var.azs, count.index))))}"
}

resource "aws_elasticache_subnet_group" "elasticache" {
  count = "${var.create_vpc && length(var.elasticache_subnets) > 0 ? 1 : 0}"

  name        = "${var.name}"
  description = "ElastiCache subnet group for ${var.name}"
  subnet_ids  = ["${aws_subnet.elasticache.*.id}"]
}

##############
# NAT Gateway
##############
# Workaround for interpolation not being able to "short-circuit" the evaluation of the conditional branch that doesn't end up being used
# Source: https://github.com/hashicorp/terraform/issues/11566#issuecomment-289417805
#
# The logical expression would be
#
#    nat_gateway_ips = var.reuse_nat_ips ? var.external_nat_ip_ids : aws_eip.nat.*.id
#
# but then when count of aws_eip.nat.*.id is zero, this would throw a resource not found error on aws_eip.nat.*.id.
locals {
  nat_gateway_ips = "${split(",", (var.reuse_nat_ips ? join(",", var.external_nat_ip_ids) : join(",", aws_eip.nat.*.id)))}"
}

resource "aws_eip" "nat" {
  count = "${var.create_vpc && (var.enable_nat_gateway && !var.reuse_nat_ips) ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0}"

  vpc = true

  tags = "${merge(var.tags, map("Name", format("%s-%s", var.name, element(var.azs, (var.single_nat_gateway ? 0 : count.index)))))}"
}

resource "aws_nat_gateway" "this" {
  count = "${var.create_vpc && var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0}"

  allocation_id = "${element(aws_eip.nat.*.id, (var.single_nat_gateway == "true" ? 0 : count.index))}"
  subnet_id     = "${element(aws_subnet.public.*.id, (var.single_nat_gateway == "true" ? 0 : count.index))}"

  tags = "${merge(var.tags, map("Name", format("%s-%s", var.name, element(var.azs, count.index))))}"

  depends_on = ["aws_internet_gateway.this"]
}

#resource "aws_route" "private_nat_gateway" {
#  count = "${var.create_vpc && var.enable_nat_gateway ? length(var.private_subnets) : 0}"
#
#  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
#  destination_cidr_block = "0.0.0.0/0"
#  nat_gateway_id         = "${element(aws_nat_gateway.this.*.id, count.index)}"
#}

######################
# VPC Endpoint for S3
######################
data "aws_vpc_endpoint_service" "s3" {
  count = "${var.create_vpc && var.enable_s3_endpoint ? 1 : 0}"

  service = "s3"
}

resource "aws_vpc_endpoint" "s3" {
  count = "${var.create_vpc && var.enable_s3_endpoint ? 1 : 0}"

  vpc_id       = "${aws_vpc.this.id}"
  service_name = "${data.aws_vpc_endpoint_service.s3.service_name}"
}

resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  count = "${var.create_vpc && var.enable_s3_endpoint ? length(var.private_subnets) : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_vpc_endpoint_route_table_association" "public_s3" {
  count = "${var.create_vpc && var.enable_s3_endpoint ? 1 : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${aws_route_table.public.id}"
}

############################
# VPC Endpoint for DynamoDB
############################
data "aws_vpc_endpoint_service" "dynamodb" {
  count = "${var.create_vpc && var.enable_dynamodb_endpoint ? 1 : 0}"

  service = "dynamodb"
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = "${var.create_vpc && var.enable_dynamodb_endpoint ? 1 : 0}"

  vpc_id       = "${aws_vpc.this.id}"
  service_name = "${data.aws_vpc_endpoint_service.dynamodb.service_name}"
}

resource "aws_vpc_endpoint_route_table_association" "private_dynamodb" {
  count = "${var.create_vpc && var.enable_dynamodb_endpoint ? length(var.private_subnets) : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.dynamodb.id}"
  route_table_id  = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_vpc_endpoint_route_table_association" "public_dynamodb" {
  count = "${var.create_vpc && var.enable_dynamodb_endpoint ? length(var.public_subnets) : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.dynamodb.id}"
  route_table_id  = "${aws_route_table.public.id}"
}

##########################
# Route table association
##########################
resource "aws_route_table_association" "private" {
  count = "${var.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0}"

  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route_table_association" "database" {
  count = "${var.create_vpc && length(var.database_subnets) > 0 ? length(var.database_subnets) : 0}"

  subnet_id      = "${element(aws_subnet.database.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route_table_association" "redshift" {
  count = "${var.create_vpc && length(var.redshift_subnets) > 0 ? length(var.redshift_subnets) : 0}"

  subnet_id      = "${element(aws_subnet.redshift.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route_table_association" "elasticache" {
  count = "${var.create_vpc && length(var.elasticache_subnets) > 0 ? length(var.elasticache_subnets) : 0}"

  subnet_id      = "${element(aws_subnet.elasticache.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route_table_association" "public" {
  count = "${var.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0}"

  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

##############
# VPN Gateway
##############
resource "aws_vpn_gateway" "this" {
  count = "${var.create_vpc && var.enable_vpn_gateway ? 1 : 0}"

  vpc_id = "${aws_vpc.this.id}"

  tags = "${merge(var.tags, map("Name", format("%s", var.name)))}"
}

resource "aws_vpn_gateway_attachment" "this" {
  count = "${var.vpn_gateway_id != "" ? 1 : 0}"

  vpc_id         = "${aws_vpc.this.id}"
  vpn_gateway_id = "${var.vpn_gateway_id}"
}

resource "aws_vpn_gateway_route_propagation" "public" {
  count = "${var.create_vpc && var.propagate_public_route_tables_vgw && (var.enable_vpn_gateway  || var.vpn_gateway_id != "") ? 1 : 0}"

  route_table_id = "${element(aws_route_table.public.*.id, count.index)}"
  vpn_gateway_id = "${element(concat(aws_vpn_gateway.this.*.id, aws_vpn_gateway_attachment.this.*.vpn_gateway_id), count.index)}"
}

resource "aws_vpn_gateway_route_propagation" "private" {
  count = "${var.create_vpc && var.propagate_private_route_tables_vgw && (var.enable_vpn_gateway || var.vpn_gateway_id != "") ? length(var.private_subnets) : 0}"

  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
  vpn_gateway_id = "${element(concat(aws_vpn_gateway.this.*.id, aws_vpn_gateway_attachment.this.*.vpn_gateway_id), count.index)}"
}

###########
# Defaults
###########
resource "aws_default_vpc" "this" {
  count = "${var.manage_default_vpc ? 1 : 0}"

  enable_dns_support   = "${var.default_vpc_enable_dns_support}"
  enable_dns_hostnames = "${var.default_vpc_enable_dns_hostnames}"
  enable_classiclink   = "${var.default_vpc_enable_classiclink}"

  tags = "${merge(var.tags, var.default_vpc_tags, map("Name", format("%s", var.default_vpc_name)))}"
}

resource "aws_default_route_table" "this" {
  count = "${var.create_vpc ? 1 : 0}"

  default_route_table_id = "${aws_vpc.this.default_route_table_id}"

  tags = "${merge(var.tags, var.default_route_table_tags, map("Name", format("%s-default", var.name)))}"
}

resource "aws_main_route_table_association" "this" {
  count = "${var.create_vpc ? 1 : 0}"

  vpc_id         = "${aws_vpc.this.id}"
  route_table_id = "${aws_default_route_table.this.default_route_table_id}"
}
