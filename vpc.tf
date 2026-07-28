# vpc.tf

resource "aws_vpc" "retail_store_vpc" {
  cidr_block           = local.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = join("-", [local.short_name, "vpc"]) })
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.retail_store_vpc.id
  cidr_block              = local.public_subnet_1_cidr
  availability_zone       = local.az_1
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                                          = join("-", [local.short_name, "public", "1"])
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  })
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.retail_store_vpc.id
  cidr_block              = local.public_subnet_2_cidr
  availability_zone       = local.az_2
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                                          = join("-", [local.short_name, "public", "2"])
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.retail_store_vpc.id
  tags   = merge(local.common_tags, { Name = join("-", [local.short_name, "igw"]) })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.retail_store_vpc.id
  tags   = merge(local.common_tags, { Name = join("-", [local.short_name, "rt"]) })
}

resource "aws_route" "default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}