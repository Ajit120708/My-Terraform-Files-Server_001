# Copilot Instructions for My-Terraform-Files-Server_001

## Project Overview
This project provisions an AWS EC2 bastion host using Terraform, with automated setup for Jenkins, Docker, AWS CLI, kubectl, eksctl, and Apache Tomcat. The infrastructure is designed for CI/CD and EKS management in a Dev environment.

## Key Files & Structure
- `main.tf`: Core AWS resources (EC2, security group), references `user-data.sh` for instance provisioning.
- `iam.tf`: IAM role, instance profile, and policy attachments for EC2/EKS/ECR access.
- `keypair.tf`: Generates and stores SSH key pair for EC2 access.
- `variables.tf`: All configurable variables (region, VPC, subnet, etc.).
- `outputs.tf`: Exposes public IP and SSH command for the bastion host.
- `user-data.sh`: Cloud-init script for EC2, installs Jenkins (on port 9090), Docker, AWS CLI, kubectl, eksctl, Tomcat, and optionally runs a custom JAR.
- `terraform.tfvars`: Used for variable overrides (not committed by default).

## Developer Workflows
- **Initialize**: `terraform init`
- **Plan**:      `terraform plan -var-file=terraform.tfvars`
- **Apply**:     `terraform apply -var-file=terraform.tfvars`
- **Destroy**:   `terraform destroy -var-file=terraform.tfvars`
- **SSH Access**: Use the output `ssh_command` and the generated `my-key.pem`.

## Patterns & Conventions
- All provisioning logic for the EC2 instance is in `user-data.sh` (idempotent, logs to `/var/log/jenkins_install.log` and `/var/log/tomcat_install.log`).
- Jenkins runs on port 9090 (not default 8080).
- Security group allows SSH (22), Jenkins (9090), and Tomcat (8080) from all IPs by default (see `allowed_ssh_cidr`).
- IAM role grants ECR, EKS, and EC2 read access to the bastion host.
- SSH key is generated and saved as `my-key.pem` in the module directory.
- Custom JAR in `/opt/app/app.jar` will be run as a systemd service if present.

## External Dependencies
- AWS provider (region set via variable)
- Ubuntu 22.04 AMI (owner: 099720109477)
- Jenkins, Docker, AWS CLI, kubectl, eksctl, Tomcat 9.0.27

## Examples
- To override the default region or subnet, set values in `terraform.tfvars` or via CLI `-var` flags.
- To add more software, extend `user-data.sh`.

## References
- See `main.tf`, `user-data.sh`, and `outputs.tf` for the main flow.
- For IAM and key management, see `iam.tf` and `keypair.tf`.

---
_If you update provisioning logic or add new resources, update this file and `README.md` to keep instructions current._
