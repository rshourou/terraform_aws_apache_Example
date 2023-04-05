variable "instance_type" {
    type = string
    description = "The size of the EC2 instance"
    default = "t2.micro"
    sensitive = false

    validation {
      condition = can(regex("^t2.", var.instance_type))
      error_message = "The instance must be a t2 type EC2 instance"    
    }
}

variable "vpc_id" {
  type = string
}

variable "public_key" {
  type = string
}