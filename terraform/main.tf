# Get the latest RHEL 9 AMI in the specified region
data "aws_ami" "rhel" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat Official Account

  filter {
    name   = "name"
    values = ["RHEL-9.*_HVM-*-x86_64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 1. RSA Private Key & AWS Key Pair Creation
resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.k8s_key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "${path.module}/${var.key_name}.pem"
  file_permission = "0400"
}

# 2. VPC & Subnet Networking
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "cloudops-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "cloudops-public-subnet" }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = { Name = "cloudops-private-subnet-1" }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}b"

  tags = { Name = "cloudops-private-subnet-2" }
}

# 3. Gateways & EIP
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "cloudops-igw" }
}

resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = { Name = "cloudops-nat-gateway" }
}

# 4. Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "cloudops-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = { Name = "cloudops-private-rt" }
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

# 5. Security Group Configuration
resource "aws_security_group" "k8s_sg" {
  name        = "k8s-cluster-sg"
  description = "Unified Security Group for CloudOps Kubernetes Cluster"
  vpc_id      = aws_vpc.main.id

  # Allow all traffic between Kubernetes cluster nodes.
  # This is required for internal Kubernetes communication.
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # [CHANGED] SSH is allowed only from the administrator's public IP.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # Public HTTP access.
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Public HTTPS access.
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Public React application access through NodePort.
  ingress {
    from_port   = 30001
    to_port     = 30001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # [CHANGED] OpenVPN is accessible only from the administrator's IP.
  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = [var.admin_cidr]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-k8s-cluster" }
}

# 6. EC2 Instances

resource "aws_instance" "k8s_master" {
  ami           = data.aws_ami.rhel.id
  instance_type = var.master_instance_type
  subnet_id     = aws_subnet.public.id

  # [CHANGED] Static private IP used by Kubernetes and /etc/hosts.
  private_ip = "10.0.1.10"

  vpc_security_group_ids      = [aws_security_group.k8s_sg.id]
  key_name                    = aws_key_pair.generated_key.key_name
  associate_public_ip_address = true

  # [CHANGED] Terraform passes node IPs to the installation script.
  user_data = templatefile("${path.module}/../scripts/install-deps.sh", {
    master_private_ip   = "10.0.1.10"
    worker_1_private_ip = "10.0.2.10"
    worker_2_private_ip = "10.0.3.10"
  })

  root_block_device {
    volume_size           = 40
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = "k8s-master" }
}

resource "aws_instance" "k8s_worker_1" {
  ami           = data.aws_ami.rhel.id
  instance_type = var.worker_instance_type
  subnet_id     = aws_subnet.private_1.id

  # [CHANGED] Static private IP used by Kubernetes and /etc/hosts.
  private_ip = "10.0.2.10"

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name               = aws_key_pair.generated_key.key_name

  # [CHANGED] Terraform passes node IPs to the installation script.
  user_data = templatefile("${path.module}/../scripts/install-deps.sh", {
    master_private_ip   = "10.0.1.10"
    worker_1_private_ip = "10.0.2.10"
    worker_2_private_ip = "10.0.3.10"
  })

  root_block_device {
    volume_size           = 40
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = "k8s-worker-1" }
}

resource "aws_instance" "k8s_worker_2" {
  ami           = data.aws_ami.rhel.id
  instance_type = var.worker_instance_type
  subnet_id     = aws_subnet.private_2.id

  # [CHANGED] Static private IP used by Kubernetes and /etc/hosts.
  private_ip = "10.0.3.10"

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name               = aws_key_pair.generated_key.key_name

  # [CHANGED] Terraform passes node IPs to the installation script.
  user_data = templatefile("${path.module}/../scripts/install-deps.sh", {
    master_private_ip   = "10.0.1.10"
    worker_1_private_ip = "10.0.2.10"
    worker_2_private_ip = "10.0.3.10"
  })

  root_block_device {
    volume_size           = 40
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = "k8s-worker-2" }
}