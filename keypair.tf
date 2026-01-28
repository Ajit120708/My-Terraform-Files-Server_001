resource "tls_private_key" "bastion_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion_key" {
  key_name   = "my-key"
  public_key = tls_private_key.bastion_key.public_key_openssh

  tags = {
    Name = "bastion-host-key"
  }
}

resource "local_file" "private_key" {
  filename        = "${path.module}/my-key.pem"
  content         = tls_private_key.bastion_key.private_key_pem
  file_permission = "0600"
}
