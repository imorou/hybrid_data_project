# =========================
# RDS Subnet Group
# =========================
resource "aws_db_subnet_group" "private" {
  name = "staging-subnet-group"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name = "staging-subnet-group"
  }
}

# =========================
# RDS PostgreSQL
# =========================
resource "aws_db_instance" "staging" {
  identifier        = "staging-db"
  engine            = "postgres"
  engine_version    = "15.16"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_subnet_group_name = aws_db_subnet_group.private.name

  vpc_security_group_ids = [
    aws_security_group.private_sg.id
  ]

  publicly_accessible = true
  username            = "imorou"
  password            = "Sblk2290"
  skip_final_snapshot = true

  tags = {
    Name = "staging-db"
  }
}



