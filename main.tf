locals {
  project_name = "Provisioner"
  ingress_rules= [
    {port= 22,
    description ="SSH" },
    {
      port= 80,
    description ="HTTP"
    }
  ]
}

data "aws_ami" "server_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "template_file" "userdata" {
  template = file("${abspath(path.module)}/userdata.yaml")
}

data "aws_vpc" "main" {
  id = var.vpc_id
}


resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.public_key
}

resource "aws_security_group" "sg_terraform" {
  name        = "sg_terraform"
  description = "Security group for HTTP"
  vpc_id      = data.aws_vpc.main.id

  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      description      = ingress.value.description
      from_port        = ingress.value.port
      to_port          = ingress.value.port
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
    } 
  }
  
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "my-server" {
  ami                    = data.aws_ami.server_ami.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.sg_terraform.id]
  user_data              = data.template_file.userdata.rendered

  provisioner "local-exec" {
    command = "echo ${self.private_ip} >> private_ips.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "echo ${self.private_ip} >> /home/ec2-user/private_ips.txt"
    ]
  }

  provisioner "file" {
    content     = "ami used : ${self.ami}"
    destination = "/home/ec2-user/barsoon.txt"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/terraform")
    host        = self.public_ip
  }

  tags = {
    Name = "${local.project_name}Server"
  }
}

resource "null_resource" "status" {
    provisioner "local-exec"{
        command = "aws ec2 wait instance-status-ok --instance-ids ${aws_instance.my-server.id} "
    }
    depends_on =[aws_instance.my-server]
  }

  resource "aws_s3_bucket" "bucket" {
  bucket = "roya-tf-test-bucket"
  depends_on = [
    aws_instance.my-server
  ]

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }

}




