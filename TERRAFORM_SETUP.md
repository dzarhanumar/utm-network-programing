# Terraform Setup (AWS VPC — what we actually used)

This is the real deployment we used for testing and the demo. Builds
a VPC with a public subnet (for `ansible-control`, our bastion) and a
private subnet (for `router1` and `router2`).

## Why 2 subnets
Basically — you don't want your "routers" exposed directly to the
internet. Only `ansible-control` gets a public IP, and it's the only
thing allowed to SSH into `router1`/`router2` (security group enforces
this). `router1`/`router2` sit in a subnet whose route table has no
route to the internet gateway — that's what actually makes it
"private" here, not the instance itself.

We skipped a NAT Gateway for the private subnet since the routers
don't need internet access — the Ubuntu AMI already ships with
`python3` and `sshd` running, which is all Ansible needs.

## Steps

1. Configure AWS CLI: `aws configure`
2. Build the infra:
   ```bash
   cd terraform
   terraform init
   terraform plan     # check what it's about to create
   terraform apply    # type yes when it asks
   ```
3. Grab the outputs:
   ```bash
   terraform output ssh_to_control_node
   terraform output router1_private_ip
   terraform output router2_private_ip
   ```
4. Copy the key + ansible folder onto the control node:
   ```bash
   scp -i network-automation-key.pem network-automation-key.pem ubuntu@<control-ip>:~/
   scp -i network-automation-key.pem -r ../ansible ubuntu@<control-ip>:~/
   ```
5. SSH in and install Ansible:
   ```bash
   ssh -i network-automation-key.pem ubuntu@<control-ip>
   sudo apt update && sudo apt install -y ansible
   ```
   (we tried `pip3 install ansible --break-system-packages` first, the
   pip version on this AMI doesn't support that flag — `apt install
   ansible` just worked instead)
6. Fill in the private IPs in `ansible/inventory/hosts-aws.ini`
7. Run it:
   ```bash
   cd ~/ansible
   ansible -i inventory/hosts-aws.ini routers -m ping
   ansible-playbook -i inventory/hosts-aws.ini playbooks/site.yml
   ```

We hit a few bugs getting this to actually run (roles not found,
undefined variable, idempotency issues on re-run) — all documented in
`PROJECT_LOG.md` with the actual error messages and how we fixed each
one.

## Cleanup
```bash
terraform destroy
```
Don't skip this — AWS keeps billing otherwise (only a few cents for a
few hours, but still).

## Don't commit these
`.gitignore` already excludes them, just double-check before pushing:
`*.tfstate`, `*.pem`, `.terraform/`
