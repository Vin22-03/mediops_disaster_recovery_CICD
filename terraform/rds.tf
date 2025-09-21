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
    description      = "Postgres from EKS Worker Nodes"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    security_groups  = ["sg-05d6874382784f490"]  # replace with actual SG ID
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
  engine_version          = "15"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  username                = "mediopsadmin"
  password                = "Mediopsadmin12345!"   # ⚠️ Use Secrets Manager in prod
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  skip_final_snapshot     = false
  publicly_accessible     = false
  multi_az                = false
  storage_encrypted       = true

  # 🔹 Backup config
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  copy_tags_to_snapshot   = true
  delete_automated_backups = true

  tags = local.tags
}

output "rds_endpoint" {
  value = aws_db_instance.rds.endpoint
}
