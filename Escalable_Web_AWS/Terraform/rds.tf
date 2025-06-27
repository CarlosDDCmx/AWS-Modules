// RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.private : subnet.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

// RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "14.5"
  instance_class         = "db.t3.micro"
  identifier             = "${var.project_name}-db"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  multi_az               = true // For high availability
  publicly_accessible    = false

  tags = {
    Name = "${var.project_name}-db-instance"
  }
}