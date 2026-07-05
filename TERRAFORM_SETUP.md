# Terraform Deployment Guide (Proper VPC: Public + Private Subnet)

This is our main Infrastructure-as-Code deployment. It builds a
realistic 2-tier VPC and is what we document as the "final"
architecture in our report.

## Why public + private subnet (not just one public subnet)

In real network engineering, you never expose a router or switch's
management interface directly to the internet. Instead, you use a
**bastion host** (a.k.a. jump host) — the only internet-facing
machine — and reach every other device through it, over a private,
internal-only network segment.

We model that here:
- **`ansible-control`** sits in the **public subnet** (has a public IP,
  its route table has a path to the Internet Gateway). It's our bastion
  AND our Ansible controller in one.
- **`router1` / `router2`** sit in the **private subnet** (no public IP,
  their route table has no path to the internet). They can only be
  reached from inside the VPC — specifically, only from `ansible-control`,
  enforced by the security group rules.

"Public" vs "private" here is purely about the **route table**:
- Public subnet's route table: `0.0.0.0/0 -> Internet Gateway`
- Private subnet's route table: only the automatic `local` route (every
  AWS route table gets this for free) — so instances in it can talk to
  other subnets in the same VPC, but never to/from the internet.

We don't need a NAT Gateway for the private subnet because Ubuntu
22.04's official AMI already ships with `python3` and `sshd` running —
exactly what Ansible needs. No package installation required on
`router1`/`router2`, so they never need outbound internet access
either.

## Prerequisites
```bash
# Install Terraform (if not already installed) - see terraform.io/downloads
aws configure   # your AWS Free Tier Access Key / Secret Key
```

## Step 1 - Initialize Terraform
```bash
cd terraform
terraform init
```
This downloads the AWS, TLS, Local, and HTTP providers.

## Step 2 - Preview what will be created
```bash
terraform plan
```
Read through this output — it should show it will create: 1 VPC, 2
subnets, 1 internet gateway, 2 route tables, 2 route table
associations, 2 security groups, 1 SSH key pair, 3 EC2 instances.
Nothing is created yet at this stage.

## Step 3 - Apply (actually build everything)
```bash
terraform apply
```
Type `yes` when prompted. Takes about 1-2 minutes. Terraform will
print outputs at the end, including a ready-to-use SSH command.

## Step 4 - Connect to the bastion / control node
```bash
terraform output ssh_to_control_node
# copy-paste the printed command, e.g.:
ssh -i network-automation-key.pem ubuntu@<public-ip>
```

## Step 5 - Get the private subnet IPs
```bash
terraform output router1_private_ip
terraform output router2_private_ip
```

## Step 6 - Copy the SSH key and Ansible project onto the bastion
From your local machine (not inside the SSH session):
```bash
scp -i network-automation-key.pem network-automation-key.pem ubuntu@<control-public-ip>:~/
scp -i network-automation-key.pem -r ../ansible ubuntu@<control-public-ip>:~/
```

## Step 7 - Install Docker + Ansible on the bastion
SSH into `ansible-control`, then:
```bash
sudo apt update && sudo apt install -y docker.io python3-pip
sudo usermod -aG docker ubuntu
pip3 install ansible --break-system-packages
chmod 400 network-automation-key.pem
```

## Step 8 - Update the Ansible inventory
Edit `~/ansible/inventory/hosts-aws.ini` on the bastion, filling in the
private IPs from Step 5:
```ini
[routers]
router1 ansible_host=<router1-private-ip>
router2 ansible_host=<router2-private-ip>

[routers:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=/home/ubuntu/network-automation-key.pem
ansible_become=true
ansible_become_method=sudo
ansible_connection=ssh
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

## Step 9 - Confirm the interface name, then run the playbook
```bash
ssh -i network-automation-key.pem ubuntu@<router1-private-ip> "ip a"
# update device_interface in ansible/group_vars/all.yml if it isn't "ens5"

cd ~/ansible
ansible -i inventory/hosts-aws.ini routers -m ping
ansible-playbook -i inventory/hosts-aws.ini playbooks/site.yml
```

## Step 10 - Collect evidence, then destroy
Screenshot: AWS Console (VPC/subnets/route tables/instances), the
successful `ansible-playbook` run, and the contents of `reports/`.
Save them into an `evidence/` folder in the repo.

Then tear everything down so nothing keeps billing:
```bash
cd terraform
terraform destroy
```
Type `yes` when prompted. This removes every resource Terraform
created, in the correct dependency order, automatically.

## Important: what NOT to commit to GitHub
The `.gitignore` in this folder already excludes these, but double
check before pushing:
- `terraform.tfstate` / `terraform.tfstate.backup` — contains resource
  IDs and could leak infrastructure details
- `*.pem` — your private SSH key
- `.terraform/` — downloaded provider binaries (large, regenerable)

## Terraform vs the AWS CLI scripts (`aws/` folder)
The `aws/*.sh` scripts (using AWS CLI directly) are kept in the repo as
a simpler, single-public-subnet alternative and as a learning
comparison. Terraform is what we used for the actual proper
public+private VPC in the final submission, since it's declarative,
repeatable, and destroy is a single command instead of a multi-step
manual teardown.
