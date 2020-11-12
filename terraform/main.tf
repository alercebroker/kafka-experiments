variable "private_key_path" {
  description = "Path to AWS .pem Keyring"
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "kafka" {
  cidr_block           = "108.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "kafka-vpc"
  }
}

resource "aws_subnet" "kafka" {
  vpc_id                  = aws_vpc.kafka.id
  cidr_block              = "108.0.0.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "kafka-subnet"
  }
}


# Internet Gateway
resource "aws_internet_gateway" "kafka" {
  vpc_id = aws_vpc.kafka.id
}

# Route table: attach Internet Gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.kafka.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kafka.id
  }
}

# Route table association with public subnets
resource "aws_route_table_association" "public-subnet" {
  subnet_id      = aws_subnet.kafka.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.kafka.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Zookeeper port"
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kafka port"
    from_port   = 9092
    to_port     = 9092
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
    Name = "allow_ssh"
  }
}

resource "aws_instance" "zookeeper" {
  ami                         = "ami-0941665311074d970"
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  subnet_id                   = aws_subnet.kafka.id
  associate_public_ip_address = true
  key_name                    = "alerce"

  tags = {
    Name = "kafka-experiment-zookeeper"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.private_key_path)
  }
}

resource "aws_instance" "kafka" {
  count                       = 1
  ami                         = "ami-0876854ad385cfee0"
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  subnet_id                   = aws_subnet.kafka.id
  associate_public_ip_address = true
  key_name                    = "alerce"

  tags = {
    Name = "kafka-experiment-kafka"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    content = templatefile("templates/server.properties", {
      zookeeper_host  = aws_instance.zookeeper.private_ip,
      zookeeper_port  = 2181,
      broker_id       = count.index + 1,
      kafka_public_ip = self.public_ip,
      kafka_port      = 9092
    })
    destination = "/tmp/server.properties"
  }

  provisioner "remote-exec" {
    inline = ["sudo mv -f /tmp/server.properties /etc/kafka/config/server.properties", "sudo systemctl restart kafka"]
  }
}

resource "aws_instance" "runner" {
  ami                         = "ami-0266160dfb05615f3"
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  subnet_id                   = aws_subnet.kafka.id
  associate_public_ip_address = true
  key_name                    = "alerce"

  tags = {
    Name = "kafka-experiment-runner"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.private_key_path)
  }
}
