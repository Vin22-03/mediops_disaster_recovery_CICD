############################################################
# rds.tf – MediOps RDS for PostgreSQL
############################################################

resource "aws_db_subnet_group" "rds_subnet" {
  name       = "${var.project}-rds-subnet"
  subnet_ids = [for s in aws_subnet.private : s.id]
  tags       = local.tags
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.project}-rds-sg"
  description = "Allow Postgres from EKS nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres from EKS SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_sg.id]  # ✅ FIX: use eks_sg from main.tf
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_db_instance" "rds" {
  identifier              = "${var.project}-postgres"
  engine                  = "postgres"
  engine_version          = "15" # stable version
  instance_class          = "db.t3.micro" # free tier friendly
  allocated_storage       = 20
  username                = "admin"
  password                = "Admin12345!"   # ⚠️ Replace with SSM/Secrets in production
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = false
  storage_encrypted       = true

  tags = local.tags
}

output "rds_endpoint" {
  value = aws_db_instance.rds.endpoint
}
