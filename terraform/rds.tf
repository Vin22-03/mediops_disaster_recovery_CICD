##########################################
# RDS PostgreSQL for MediOps
##########################################

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "${var.project}-rds-sg"
  description = "Allow Postgres from EKS nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Postgres from EKS nodes"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.eks_nodes.id] # allow EKS nodes
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-rds-sg"
  }
}

# Subnet Group for RDS (use private subnets)
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project}-rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project}-rds-subnet-group"
  }
}

# RDS Instance (Free Tier)
resource "aws_db_instance" "rds" {
  identifier              = "${var.project}-db"
  engine                  = "postgres"
  engine_version          = "15.3"
  instance_class          = "db.t3.micro"       # Free-tier eligible
  allocated_storage       = 20                  # 20GB
  max_allocated_storage   = 100
  username                = "mediopsuser"
  password                = "MediOpsPass123!"   # ⚠️ Change later / move to SSM
  db_name                 = "mediopsdb"
  port                    = 5432
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  skip_final_snapshot     = true                # avoid snapshot charges
  deletion_protection     = false
  publicly_accessible     = false               # only inside VPC

  tags = {
    Name = "${var.project}-rds"
  }
}
