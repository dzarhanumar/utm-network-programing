# AWS Setup (CLI version — not the one we ended up using)

We wrote this first using plain AWS CLI commands, before switching to
Terraform for the real submission. Keeping it here as a backup / in
case anyone wants to compare CLI vs Terraform.

**The version we actually deployed and tested is in
`TERRAFORM_SETUP.md`** — it has a proper public + private subnet
split. This CLI version only sets up a single public subnet (simpler,
but less realistic).

## If you want to try it anyway
```bash
aws configure
cd aws/
chmod +x setup-vpc-and-ec2.sh
./setup-vpc-and-ec2.sh
```
This builds 1 VPC, 1 public subnet, and 3 EC2 instances (all with
public IPs — no private subnet here). Same idea after that: SSH into
`ansible-control`, install Ansible, copy the `ansible/` folder over,
run the playbook.

## Cleanup
```bash
./teardown.sh <VPC_ID> <SUBNET_ID> <SG_ID>
```
(The values are printed at the end of `setup-vpc-and-ec2.sh`.)
