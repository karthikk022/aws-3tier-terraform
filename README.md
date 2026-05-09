# AWS 3-Tier Architecture with Terraform

A production-ready, highly available three-tier architecture on AWS, provisioned entirely with Terraform.

## Architecture

```
                              Internet
                                 |
                            [Web ALB] (Public)
                                 |
                      +----------+----------+
                      |                     |
                 [Web EC2]            [Web EC2]
                 (Public Subs)       (Public Subs)
                      |                     |
                      +----------+----------+
                                 |
                          [App ALB] (Internal)
                                 |
                      +----------+----------+
                      |                     |
                 [App EC2]            [App EC2]
                 (Private Subs)      (Private Subs)
                      |                     |
                      +----------+----------+
                                 |
                            [RDS MySQL]
                          (DB Private Subs)
```

### Tiers

| Tier | Layer | Access | Subnet Type |
|------|-------|--------|-------------|
| **Web** | Public ALB + EC2 (Nginx) | Internet-facing | Public |
| **App** | Internal ALB + EC2 (Node.js) | VPC-only | Private |
| **DB** | RDS (MySQL/PostgreSQL) | App tier only | Private (Isolated) |

### Key Features

- **Multi-AZ** deployment across 2 Availability Zones for high availability.
- **Auto Scaling Groups** with CPU-based scaling policies and CloudWatch Alarms.
- **NAT Gateway** for secure outbound internet access from private subnets.
- **Security Groups & NACLs** for multi-layered network security.
- **HTTPS Ready** with ALB listener configuration and ACM integration support.
- **Nginx Reverse Proxy** configured on the web tier to forward traffic to the app tier.
- **Database Integration** in the app tier with `mysql2` and connection pooling.
- **Secrets Management** using AWS Secrets Manager for secure credential handling.
- **Automated Backups** for RDS with configurable retention periods.
- **Dynamic AMI Selection** using Terraform data sources for the latest Amazon Linux 2023.
- **CI/CD Pipeline** with GitHub Actions for automated infrastructure deployment.
- **Enhanced Monitoring** with CloudWatch Alarms for CPU and health checks.

## Prerequisites

- [AWS Account](https://aws.amazon.com/free/)
- [Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) configured with `aws configure`

## Project Structure

```
.
├── main.tf                  # Root module - orchestrates all tiers
├── variables.tf             # Root variables with defaults
├── outputs.tf               # Root outputs
├── provider.tf              # Provider configuration
├── terraform.tfvars.example # Example variable values
└── modules/
    ├── vpc/                 # VPC, subnets, IGW, NAT Gateway, route tables
    ├── web/                 # Web ALB, Launch Template, ASG, scaling policies
    ├── app/                 # Internal ALB, Launch Template, ASG, scaling policies
    └── database/            # RDS subnet group, security group, DB instance
```

## Deployment

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/aws-3-tier-terraform.git
cd aws-3-tier-terraform

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (db_username, db_password, etc.)

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy
terraform apply

# Destroy (when done)
terraform destroy
```

## Security

- Database is deployed in private subnets with no direct internet access
- App tier only allows traffic from the web security group
- Database only allows traffic from the app security group
- NAT Gateway enables outbound internet for private instances (updates, packages)
- RDS storage is encrypted at rest

## Customization

Edit `terraform.tfvars` to customize:

- **Instance sizes**: `web_instance_type`, `app_instance_type`, `db_instance_class`
- **Scaling limits**: `web_min_size`, `web_max_size`, etc.
- **Database engine**: Switch between `mysql` and `postgres`
- **CIDR ranges**: VPC and subnet network ranges

## Clean Up

```bash
terraform destroy
```
