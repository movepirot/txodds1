output "private_subnets" {
    value = aws_subnet.private_subnets
}

output "vpc_id" {
    value = aws_vpc.txodds.id
}

