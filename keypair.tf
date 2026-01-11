resource "aws_key_pair" "bastion_key" {
  key_name   = "my-key"
  public_key = file("${path.module}/my-key.pem.pub")

  tags = {
    Name = "bastion-host-key"
  }
}
