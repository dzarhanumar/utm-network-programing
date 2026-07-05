# AWS Deployment Guide

This documents how we deployed the network automation project on real
AWS infrastructure (VPC + EC2), instead of only running it locally
with Docker. This is included in our GitHub repo as evidence of the
project's real-world deployment for the report.

## Architecture

```
 Your laptop --SSH--> [ VPC 10.0.0.0/16 - ap-southeast-1 ]
                            |
                    Internet Gateway
                            |
                Public Subnet 10.0.1.0/24
                            |
        -----------------------------------------
        |                  |                    |
  ansible-control       router1              router2
  (Docker + Ansible)   (Ubuntu EC2)         (Ubuntu EC2)
        --------SSH (private IP, same security group)-------
```

- **1 VPC** (`10.0.0.0/16`) — our own isolated network, built from scratch
- **1 public subnet** (`10.0.1.0/24`) — hosts all 3 EC2 instances
- **1 Internet Gateway** — lets instances reach the internet / be reached via public IP
- **1 route table** — routes `0.0.0.0/0` traffic to the Internet Gateway
- **1 security group** — allows SSH (port 22) from our IP, and SSH between
  the 3 instances (so `ansible-control` can reach `router1`/`router2`)
- **3 EC2 instances** (Ubuntu 22.04, t3.micro — free tier eligible):
  - `ansible-control`: runs Docker + our Ansible control container
  - `router1`, `router2`: simulated network devices, targeted by Ansible

## Why this design
Instead of hardcoding real router hardware (not available to us), we
use plain Ubuntu EC2 instances as configuration targets. Ansible
doesn't care whether the target is a real Cisco device, a Docker
container, or an EC2 instance — it just needs SSH access. This lets us
demonstrate the same 6 device-configuration tasks (IP address, user
account, banner, interface description, static route, retrieve
device info) against real cloud infrastructure, on top of a VPC we
built from scratch ourselves.

## Step-by-step

### 1. Prerequisites
```bash
aws configure
# Enter your AWS Free Tier Access Key ID, Secret Key, region (ap-southeast-1)
```

### 2. Build the VPC + EC2 instances
```bash
cd aws/
chmod +x setup-vpc-and-ec2.sh
./setup-vpc-and-ec2.sh
```
This script creates the VPC, subnet, Internet Gateway, route table,
security group, key pair, and launches all 3 EC2 instances. It prints
`VPC_ID`, `SUBNET_ID`, and `SG_ID` at the end — **save these**, you'll
need them for teardown later.

### 3. Get the instances' IP addresses
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ansible-control,router1,router2" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,PublicIpAddress,PrivateIpAddress]' \
  --output table --region ap-southeast-1
```

### 4. Copy the SSH key and Ansible project onto ansible-control
```bash
scp -i network-automation-key.pem network-automation-key.pem ubuntu@<ansible-control-public-ip>:~/
scp -i network-automation-key.pem -r ../ansible ubuntu@<ansible-control-public-ip>:~/
```

### 5. SSH into ansible-control and install Docker + Ansible
```bash
ssh -i network-automation-key.pem ubuntu@<ansible-control-public-ip>

# on the instance:
sudo apt update && sudo apt install -y docker.io python3-pip
sudo usermod -aG docker ubuntu
pip3 install ansible --break-system-packages
chmod 400 network-automation-key.pem
```

### 6. Update the inventory with router1/router2's PRIVATE IPs
Edit `ansible/inventory/hosts-aws.ini` and replace the placeholder IPs
with the actual private IPs from step 3.

### 7. Confirm the interface name on the target devices
```bash
ssh -i network-automation-key.pem ubuntu@<router1-private-ip> "ip a"
```
Update `device_interface` in `ansible/group_vars/all.yml` if it's not `ens5`.

### 8. Run the playbook
```bash
cd ~/ansible
ansible -i inventory/hosts-aws.ini routers -m ping
ansible-playbook -i inventory/hosts-aws.ini playbooks/site.yml
```

### 9. Collect evidence for the report
- Screenshot the AWS Console: VPC, Subnets, Route tables, EC2 instances (all "running")
- Screenshot the terminal output of `ansible-playbook` running successfully
- Copy the generated reports from `reports/` folder
- Include all of the above in the GitHub repo (e.g. under `evidence/`)

### 10. Clean up (IMPORTANT — do this before/after submission)
```bash
cd aws/
./teardown.sh <VPC_ID> <SUBNET_ID> <SG_ID>
```
This terminates all instances and removes the VPC, subnet, IGW, route
table, and security group so nothing keeps running (and potentially
billing) after you're done.

## Cost note
3x t3.micro instances running for a few hours costs only a few cents,
well within AWS Free Tier credits/allowance either way. The main risk
is forgetting to terminate instances — always run the teardown script
once you've finished testing and taking screenshots.
