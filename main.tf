######
# VPC
######
resource "aws_vpc" "this" {
  cidr_block                       = "${var.cidr}"
  instance_tenancy                 = "${var.instance_tenancy}"
  enable_dns_hostnames             = "${var.enable_dns_hostnames}"
  enable_dns_support               = "${var.enable_dns_support}"
  assign_generated_ipv6_cidr_block = true

  tags                             = "${merge(var.tags, var.vpc_tags, map("Name", format("%s", var.name)))}"
}

###################
# DHCP Options Set
###################
resource "aws_vpc_dhcp_options" "this" {
  count                = "${var.enable_dhcp_options ? 1 : 0}"

  domain_name          = "${var.dhcp_options_domain_name}"
  domain_name_servers  = "${var.dhcp_options_domain_name_servers}"
  ntp_servers          = "${var.dhcp_options_ntp_servers}"
  netbios_name_servers = "${var.dhcp_options_netbios_name_servers}"
  netbios_node_type    = "${var.dhcp_options_netbios_node_type}"

  tags                 = "${merge(var.tags, var.dhcp_options_tags, map("Name", format("%s", var.name)))}"
}

###############################
# DHCP Options Set Association
###############################
resource "aws_vpc_dhcp_options_association" "this" {
  count           = "${var.enable_dhcp_options ? 1 : 0}"

  vpc_id          = "${aws_vpc.this.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.this.id}"
}

###################
# Internet Gateway
###################
resource "aws_internet_gateway" "this" {
  count  = "${var.public_subnet_count > 0 ? 1 : 0}"

  vpc_id = "${aws_vpc.this.id}"

  tags   = "${merge(var.tags, map("Name", format("%s", var.name)))}"
}

################
# Publiс routes
################
resource "aws_route_table" "public" {
  count            = "${var.public_subnet_count > 0 ? 1 : 0}"

  vpc_id           = "${aws_vpc.this.id}"
  propagating_vgws = ["${var.public_propagating_vgws}"]

  tags             = "${merge(var.tags, var.public_route_table_tags, map("Name", format("%s-public", var.name)))}"

}

resource "aws_route" "public_internet_gateway" {
  count                  = "${var.public_subnet_count > 0 ? 1 : 0}"

  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.this.id}"
}

resource "aws_route" "ipv6_public_internet_gateway" {
  count                       = "${var.public_subnet_count > 0 ? 1 : 0}"

  route_table_id              = "${aws_route_table.public.id}"
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = "${aws_internet_gateway.this.id}"
}

#################
# Private routes
#################
resource "aws_route_table" "private" {
  count            = "${var.private_subnet_count}"

  vpc_id           = "${aws_vpc.this.id}"
  propagating_vgws = ["${var.private_propagating_vgws}"]

  tags             = "${merge(var.tags, var.private_route_table_tags, map("Name", format("%s-private-%s", var.name, element(var.azs, count.index))))}"


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
  count                           = "${var.public_subnet_count}"

  vpc_id                          = "${aws_vpc.this.id}"
  cidr_block                      = "${cidrsubnet(aws_vpc.this.cidr_block,8,count.index+1)}"
  availability_zone               = "${element(var.azs, count.index)}"
  map_public_ip_on_launch         = "${var.map_public_ip_on_launch}"

  assign_ipv6_address_on_creation = true
  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.this.ipv6_cidr_block,8,count.index+1)}"

  tags                            = "${merge(var.tags, var.public_subnet_tags, map("Name", format("%s-public-%s", var.name, element(var.azs, count.index))))}"
}

#################
# Private subnet
#################
resource "aws_subnet" "private" {
  count                           = "${var.private_subnet_count}"

  vpc_id                          = "${aws_vpc.this.id}"
  cidr_block                      = "${cidrsubnet(aws_vpc.this.cidr_block,8,count.index+11)}"
  availability_zone               = "${element(var.azs, count.index)}"

  assign_ipv6_address_on_creation = true
  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.this.ipv6_cidr_block,8,count.index+11)}"

  tags                            = "${merge(var.tags, var.private_subnet_tags, map("Name", format("%s-private-%s", var.name, element(var.azs, count.index))))}"
}


resource "aws_route" "private_nat_gateway" {
  count                   = "${var.enable_nat_gateway == "true" ? var.private_subnet_count : 0}"

  route_table_id          = "${element(aws_route_table.private.*.id, count.index)}"
  destination_cidr_block  = "0.0.0.0/0"
  nat_gateway_id          = "${element(aws_nat_gateway.this.*.id, count.index)}"
}

resource "aws_route" "private_egress_only_gateway" {
  count                       = "${var.enable_nat_gateway == "true" ? var.private_subnet_count : 0}"
  route_table_id              = "${element(aws_route_table.private.*.id, count.index)}"
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = "${element(aws_egress_only_internet_gateway.eigw.*.id, count.index)}"
}


##################
# Database subnet
##################
resource "aws_subnet" "database" {
  count                           = "${var.database_subnet_count}"

  vpc_id                          = "${aws_vpc.this.id}"
  cidr_block                      = "${cidrsubnet(aws_vpc.this.cidr_block,8,count.index+21)}"
  availability_zone               = "${element(var.azs, count.index)}"

  assign_ipv6_address_on_creation = true
  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.this.ipv6_cidr_block,8,count.index+21)}"

  tags                            = "${merge(var.tags, var.database_subnet_tags, map("Name", format("%s-db-%s", var.name, element(var.azs, count.index))))}"
}

resource "aws_db_subnet_group" "database" {
  count       = "${var.database_subnet_count > 0 ? 1 : 0}"

  name        = "${lower(var.name)}"
  description = "Database subnet group for ${var.name}"
  subnet_ids  = ["${aws_subnet.database.*.id}"]

  tags        = "${merge(var.tags, map("Name", format("%s", var.name)))}"
}

##################
# Redshift subnet
##################
resource "aws_subnet" "redshift" {
  count                           = "${var.redshift_subnet_count}"

  vpc_id                          = "${aws_vpc.this.id}"
  cidr_block                      = "${cidrsubnet(aws_vpc.this.cidr_block,8,count.index+31)}"
  availability_zone               = "${element(var.azs, count.index)}"
  assign_ipv6_address_on_creation = true
  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.this.ipv6_cidr_block,8,count.index+31)}"

  tags                            = "${merge(var.tags, var.redshift_subnet_tags, map("Name", format("%s-redshift-%s", var.name, element(var.azs, count.index))))}"
}

resource "aws_redshift_subnet_group" "redshift" {
  count       = "${var.redshift_subnet_count > 0 ? 1 : 0}"

  name        = "${var.name}"
  description = "Redshift subnet group for ${var.name}"
  subnet_ids  = ["${aws_subnet.redshift.*.id}"]

  tags        = "${merge(var.tags, map("Name", format("%s", var.name)))}"
}

#####################
# ElastiCache subnet
#####################
resource "aws_subnet" "elasticache" {
  count                           = "${var.elasticache_subnet_count}"

  vpc_id                          = "${aws_vpc.this.id}"
  cidr_block                      = "${cidrsubnet(aws_vpc.this.cidr_block,8,count.index+41)}"
  availability_zone               = "${element(var.azs, count.index)}"
  assign_ipv6_address_on_creation = true
  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.this.ipv6_cidr_block,8,count.index+41)}"

  tags                            = "${merge(var.tags, var.elasticache_subnet_tags, map("Name", format("%s-elasticache-%s", var.name, element(var.azs, count.index))))}"
}

resource "aws_elasticache_subnet_group" "elasticache" {
  count       = "${var.elasticache_subnet_count > 0 ? 1 : 0}"

  name        = "${var.name}"
  description = "ElastiCache subnet group for ${var.name}"
  subnet_ids  = ["${aws_subnet.elasticache.*.id}"]
}

##############
# NAT Gateway
##############
resource "aws_eip" "nat" {
  count = "${var.enable_nat_gateway == "true" ? (var.single_nat_gateway == "true" ? 1 : var.private_subnet_count) : 0}"
  vpc   = true
}

resource "aws_nat_gateway" "this" {
  count = "${var.enable_nat_gateway == "true" ? (var.single_nat_gateway == "true" ? 1 : var.private_subnet_count) : 0}"

  allocation_id = "${element(aws_eip.nat.*.id, (var.single_nat_gateway == "true" ? 0 : count.index))}"
  subnet_id     = "${element(aws_subnet.public.*.id, (var.single_nat_gateway == "true" ? 0 : count.index))}"

  tags = "${merge(var.tags, map("Name", format("%s-%s", var.name, element(var.azs, count.index))))}"

  depends_on = ["aws_internet_gateway.this"]
}

resource "aws_egress_only_internet_gateway" "eigw" {
  count = "${var.enable_nat_gateway == "true" ? (var.private_subnet_count > 0 ? 1 : 0) : 0}"
  vpc_id = "${aws_vpc.this.id}"
}

######################
# VPC Endpoint for S3
######################
data "aws_vpc_endpoint_service" "s3" {
#  count = "${var.enable_s3_endpoint}"

  service = "s3"
}

resource "aws_vpc_endpoint" "s3" {
#  count = "${var.enable_s3_endpoint}"

  vpc_id       = "${aws_vpc.this.id}"
  service_name = "${data.aws_vpc_endpoint_service.s3.service_name}"
}

# Put the S3 endpoint into the private and public VPC routing tables
resource "aws_vpc_endpoint_route_table_association" "s3_private" {
  count = "${var.enable_s3_endpoint ? var.private_subnet_count : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_vpc_endpoint_route_table_association" "s3_public" {
  count = "${var.enable_s3_endpoint ? var.public_subnet_count : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id = "${aws_route_table.public.id}"
}

############################
# VPC Endpoint for DynamoDB
############################
data "aws_vpc_endpoint_service" "dynamodb" {
#  count = "${var.enable_dynamodb_endpoint}"

  service = "dynamodb"
}

resource "aws_vpc_endpoint" "dynamodb" {
#  count = "${var.enable_dynamodb_endpoint}"

  vpc_id       = "${aws_vpc.this.id}"
  service_name = "${data.aws_vpc_endpoint_service.dynamodb.service_name}"
}

resource "aws_vpc_endpoint_route_table_association" "private_dynamodb" {
  count = "${var.enable_dynamodb_endpoint ? var.private_subnet_count : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.dynamodb.id}"
  route_table_id  = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_vpc_endpoint_route_table_association" "public_dynamodb" {
  count = "${var.enable_dynamodb_endpoint ? var.public_subnet_count : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.dynamodb.id}"
  route_table_id  = "${aws_route_table.public.id}"
}


##########################
# Route table association
##########################
resource "aws_route_table_association" "private" {
  count          = "${var.private_subnet_count}"

  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route_table_association" "database" {
  count          = "${var.database_subnet_count}"

  subnet_id      = "${element(aws_subnet.database.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route_table_association" "redshift" {
  count          = "${var.redshift_subnet_count}"

  subnet_id      = "${element(aws_subnet.redshift.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}


resource "aws_route_table_association" "elasticache" {
  count          = "${var.elasticache_subnet_count}"

  subnet_id      = "${element(aws_subnet.elasticache.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route_table_association" "public" {
  count          = "${var.public_subnet_count}"

  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}