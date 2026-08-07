data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "txodds" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags = {
        Name = "txodds-vpc"
      }
  }

resource "aws_subnet" "public_subnets" {
  count = length(var.public_cidrs)
  vpc_id                  = aws_vpc.txodds.id
  cidr_block              = element(var.public_cidrs, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name                                        = "Public Subnet ${count.index + 1}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}"      = "shared"
  }
}

resource "aws_subnet" "private_subnets" {
  count = length(var.private_cidrs)
  vpc_id            = aws_vpc.txodds.id
  cidr_block        = element(var.private_cidrs, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name                                        = "Private Subnet ${count.index + 1}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}"      = "shared"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.txodds.id
  tags = {
    Name = "IGW"
  }
}

resource "aws_eip" "nat" {
  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id  = aws_subnet.public_subnets[0].id
  tags = {
    Name = "txodds-nat-gateway"
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.txodds.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public rt"
  }
}

resource "aws_route_table_association" "public_association" {
  count = length(var.public_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.txodds.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "private rt"
  }
}

resource "aws_route_table_association" "private_association" {
  count = length(var.private_cidrs)
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = aws_route_table.private.id
}