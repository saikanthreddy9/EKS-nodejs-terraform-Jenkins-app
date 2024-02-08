data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

# private key
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# aws keypair
resource "aws_key_pair" "key_pair" {
  depends_on = [tls_private_key.private_key]
  key_name   = var.key_name
  public_key = tls_private_key.private_key.public_key_openssh
}


resource "aws_security_group" "web_traffic" {
  name        = "Allow web traffic"
  description = "Allow ssh and standard http/https ports inbound and everything outbound"
  vpc_id      = module.vpc.vpc_id
  dynamic "ingress" {
    iterator = port
    for_each = var.ingressrules
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Terraform" = "true"
  }
}

resource "aws_instance" "jenkins" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.small"
  vpc_security_group_ids = [aws_security_group.web_traffic.id]
  key_name        = var.key_name
  subnet_id              = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = true
  provisioner "remote-exec" {
    inline = [
      "wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -",
      "echo deb http://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list",
      "sudo apt update -qq",
      "sudo apt install -y default-jre",
      "sudo apt install -y jenkins",
      "sudo systemctl start jenkins",
      "sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080",
      "sudo sh -c \"iptables-save > /etc/iptables.rules\"",
      "echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections",
      "echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections",
      "sudo apt-get -y install iptables-persistent",
      "sudo ufw allow 8080",
      "sudo apt install -y apt-transport-https ca-certificates curl software-properties-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable\"",
      "sudo apt update",
      "sudo apt install -y docker-ce",
      "sudo usermod -aG docker ubuntu",
      "sudo usermod -aG docker jenkins",
      "newgrp docker"
    ]
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.private_key.private_key_pem
  }

  tags = {
    "Name"      = "Jenkins_Server"
    "Terraform" = "true"
  }
}

variable "ingressrules" {
  type    = list(number)
  default = [80, 443, 22, 8080]
}

variable "key_name" {
  default = "ec2-instance-key"
}

output "ssh_private_key" {
  value = "${tls_private_key.private_key.private_key_pem}"
  sensitive = true
}