# Define the VPC
provider "aws" {
  region = "eu-central-1"
}

data "aws_availability_zones" "available" {
}

resource "aws_vpc" "myvpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "myvpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.myvpc.id

}

# Define the public subnet
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index}"
  }
}

# Define the private subnet
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index}"
  }
}

# Define the database subnet
resource "aws_subnet" "db" {
  count             = length(var.db_subnet_cidrs)
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = var.db_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "db-subnet-${count.index}"
  }
}

# Create a route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "public-route-table"
  }
}

# Create a route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat[0].id
  }

  tags = {
    Name = "private-route-table"
  }
}

# Associate the public subnets with the public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public[*].id)
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public.id

}

# Associate the private subnets with the private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private[*].id)
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private.id

}

resource "aws_eip" "nat" {
  count  = length(var.private_subnet_cidrs)
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  count         = length(var.private_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = element(aws_subnet.public[*].id, count.index)
  depends_on    = [aws_internet_gateway.main]

}



# Define a security group for public subnets (allowing HTTP and SSH)
resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Security group for public subnets"

  vpc_id = aws_vpc.myvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "public-sg"
  }

}

# Define a security group for private subnets (allowing necessary traffic)
resource "aws_security_group" "private_sg" {
  name        = "private-sg"
  description = "Security group for private subnets"

  vpc_id = aws_vpc.myvpc.id

}


resource "aws_instance" "jenkinsMaster" {
  ami                    = "ami-0ab1a82de7ca5889c"
  instance_type          = "t2.micro"
  key_name               = "jenkinskey"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  tags = {
    Name = "JenkinsMaster"
  }

}


resource "aws_instance" "ansiblemaster" {
  ami                    = "ami-0ab1a82de7ca5889c"
  instance_type          = "t2.micro"
  key_name               = "jenkinskey"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  tags = {
    Name = "ansiblemaster"
  }

}
