variable "private_key_path" {
  description = "Path to AWS .pem Keyring"
}

variable "pipeline_scale" {
  description = "Number of instances with the full pipeline"
  default     = 1
}

variable "simulator_scale" {
  description = "Number of simulator containers to run"
  default     = 1
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

  ingress {
    description = "JMX port"
    from_port   = 7075
    to_port     = 7075
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus port"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana port"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodeExporter port"
    from_port   = 9100
    to_port     = 9100
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
  ami                         = "ami-0698fe54008f8e70e"
  instance_type               = "t2.small"
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
  count                       = 3
  ami                         = "ami-03b76203cdb08c4ef"
  instance_type               = "t2.xlarge"
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  subnet_id                   = aws_subnet.kafka.id
  associate_public_ip_address = true
  key_name                    = "alerce"

  tags = {
    Name = "kafka-experiment-kafka-${count.index}"
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
    inline = [
      "sudo mv -f /tmp/server.properties /etc/kafka/config/server.properties",
      "sudo systemctl restart kafka"
    ]
  }


}

resource "aws_instance" "prometheus" {
  ami                         = "ami-0ac9b89c4afaff9f7"
  instance_type               = "t2.small"
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  subnet_id                   = aws_subnet.kafka.id
  associate_public_ip_address = true
  key_name                    = "alerce"

  tags = {
    Name = "kafka-experiment-prometheus"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.private_key_path)
  }
  provisioner "file" {
    content = templatefile("templates/prometheus.yml", {
      kafka1_ip    = aws_instance.kafka[0].private_ip,
      kafka2_ip    = aws_instance.kafka[1].private_ip,
      kafka3_ip    = aws_instance.kafka[2].private_ip,
      zookeeper_ip = aws_instance.zookeeper.private_ip,
      simulator_ip = aws_instance.simulator.private_ip,
      pipeline_ip  = aws_instance.pipeline.*.private_ip,
      jmx_port     = 7075
    })
    destination = "/tmp/prometheus.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv -f /tmp/prometheus.yml /etc/prometheus/prometheus.yml",
      "sudo systemctl restart prometheus"
    ]
  }
}

resource "aws_instance" "simulator" {
  ami                         = "ami-0a46ac9025b7762cc"
  instance_type               = "t2.2xlarge"
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  subnet_id                   = aws_subnet.kafka.id
  associate_public_ip_address = true
  key_name                    = "alerce"

  tags = {
    Name = "kafka-experiment-simulator"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    content = templatefile("templates/simulator_docker_compose.yml", {
      kafka1_private_ip = aws_instance.kafka[0].private_ip,
      kafka2_private_ip = aws_instance.kafka[1].private_ip,
      kafka3_private_ip = aws_instance.kafka[2].private_ip,
      kafka_port        = 9092
    })
    destination = "/tmp/simulator_docker_compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv -f /tmp/simulator_docker_compose.yml /home/ubuntu/experiment/vera_rubin_simulator/docker-compose.yml",
      "cd /home/ubuntu/experiment/vera_rubin_simulator",
      "sudo docker-compose up -d --scale simulator_producer=${var.simulator_scale}",
    ]
  }
}

resource "aws_instance" "pipeline" {
  count                       = var.pipeline_scale
  ami                         = "ami-0a46ac9025b7762cc"
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  subnet_id                   = aws_subnet.kafka.id
  associate_public_ip_address = true
  key_name                    = "alerce"

  tags = {
    Name = "kafka-experiment-pipeline-${count.index}"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    content = templatefile("templates/dummy_step_docker_compose.yml", {
      kafka1_private_ip = aws_instance.kafka[0].private_ip,
      kafka2_private_ip = aws_instance.kafka[1].private_ip,
      kafka3_private_ip = aws_instance.kafka[2].private_ip,
      kafka_port        = 9092
    })
    destination = "/tmp/dummy_step_docker_compose.yml"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mv -f /tmp/dummy_step_docker_compose.yml /home/ubuntu/experiment/dummy_step/docker-compose.yml",
      "cd /home/ubuntu/experiment/dummy_step",
      "sudo docker-compose up -d",
    ]
  }
}
