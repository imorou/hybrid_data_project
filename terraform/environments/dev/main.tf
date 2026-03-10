# =========================
# AWS Provider
# =========================
provider "aws" {
  region = "eu-west-1" # Ireland
}

# =========================
# VPC
# =========================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "hybrid-platform-vpc"
  }
}

# =========================
# Internet Gateway
# =========================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "hybrid-platform-igw"
  }
}

# =========================
# Public Subnets
# =========================
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-b"
  }
}

# =========================
# Private Subnets
# =========================
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.101.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "private-subnet-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.102.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "private-subnet-b"
  }
}

# =========================
# Route Tables
# =========================
# Public route table → Internet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Association des subnets publics à la route table publique
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Private route table → NAT (à créer ensuite)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# =========================
# Security Groups
# =========================

# SG pour les services publics (HTTP, HTTPS, SSH)
resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Allow HTTP, HTTPS, SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "public-sg"
  }
}

# SG pour les ressources privées (ex: RDS)
resource "aws_security_group" "private_sg" {
  name        = "private-sg"
  description = "Allow private communication"
  vpc_id      = aws_vpc.main.id

  # autoriser tout trafic depuis public_sg (optionnel selon ton architecture)
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.public_sg.id]
  }

  # autoriser tout le trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-sg"
  }
}
# Autoriser l'accès à RDS depuis ton IP publique
resource "aws_security_group_rule" "rds_access_from_my_ip" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.private_sg.id
  cidr_blocks       = ["41.79.219.122/32"] # <-- remplace par ton IP publique
}




# =========================
# Private Subnets
# =========================

resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-a"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-b"
  }
}


# =========================
# Key Pair for Bastion
# =========================
resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# =========================
# Latest Ubuntu AMI
# =========================
data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}



# =========================
# Bastion Host
# =========================
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  subnet_id = aws_subnet.public_a.id

  vpc_security_group_ids = [
    aws_security_group.public_sg.id
  ]

  key_name = aws_key_pair.bastion_key.key_name

  associate_public_ip_address = true

  tags = {
    Name = "bastion-host"
  }
}


# =========================
# IAM Role & Policy pour ETL
# =========================

# Policy IAM pour ETL
resource "aws_iam_policy" "etl_policy" {
  name = "etl-policy"
  path = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::imorou_data_lake",
          "arn:aws:s3:::imorou_data_lake/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds:*",
          "redshift:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Role IAM pour ETL
resource "aws_iam_role" "etl_role" {
  name = "etl-role"
  path = "/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = {
    Name        = "ETL Role"
    Environment = "staging"
  }
}

# Attachement de la policy au role
resource "aws_iam_role_policy_attachment" "etl_attach" {
  role       = aws_iam_role.etl_role.name
  policy_arn = aws_iam_policy.etl_policy.arn
}

# =========================
# S3 Data Lake Bucket
# =========================
resource "aws_s3_bucket" "data_lake" {
  bucket = "imoroudatalake"
  region = "eu-west-1"

  tags = {
    Name        = "Data Lake"
    Environment = "staging"
  }
}

# Versioning activé
resource "aws_s3_bucket_versioning" "data_lake_versioning" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Chiffrement côté serveur
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake_sse" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Politique IAM pour le rôle ETL
resource "aws_s3_bucket_policy" "data_lake_policy" {
  bucket = aws_s3_bucket.data_lake.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.etl_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.data_lake.arn}",
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      }
    ]
  })
}

# =========================
# IAM Role pour Redshift
# =========================
resource "aws_iam_role" "redshift_role" {
  name = "redshift-etl-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "Redshift ETL Role"
    Environment = "staging"
  }
}

# =========================
# IAM Policy pour accéder au Data Lake
# =========================
resource "aws_iam_policy" "redshift_s3_policy" {
  name = "redshift-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      }
    ]
  })
}

# Attachement de la policy au rôle Redshift
resource "aws_iam_role_policy_attachment" "redshift_s3_attach" {
  role       = aws_iam_role.redshift_role.name
  policy_arn = aws_iam_policy.redshift_s3_policy.arn
}

