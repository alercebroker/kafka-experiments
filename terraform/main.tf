variable "private_key_path" {
  description = "Path to AWS .pem Keyring"
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 2181
    to_port     = 2181
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
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  associate_public_ip_address = true
  key_name                    = "alerce"

  tags = {
    Name = "experiment-zookeeper"
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
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  associate_public_ip_address = true
  key_name                    = "alerce"
  depends_on                  = [aws_instance.zookeeper]

  tags = {
    Name = "experiment-kafka"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    content     = templatefile("templates/server.properties", { zookeeper_host = aws_instance.zookeeper.private_ip, zookeeper_port = 2181, broker_id = count.index + 1})
    destination = "/tmp/server.properties"
  }

  provisioner "remote-exec" {
    inline = ["sudo mv -f /tmp/server.properties /etc/kafka/config/server.properties"]
  }
}
