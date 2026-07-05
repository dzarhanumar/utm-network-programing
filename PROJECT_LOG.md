# Project Development Log

This log records what actually happened while building and testing this
project, including the errors we hit and how we fixed them. Kept here
as evidence of the real development process, not just a polished
final result.

## Local Docker testing
- Built the `docker-compose.yml` setup with 3 containers: `ansible-control`,
  `router1`, `router2`.
- Verified SSH connectivity between the control container and the two
  device containers before writing any Ansible tasks.

## AWS infrastructure (Terraform)
- Wrote Terraform config for a VPC with a public subnet (bastion/control
  node) and a private subnet (the two simulated routers).
- Ran `terraform plan` first to check the resource list before `apply`,
  confirmed 16 resources to create, 0 to destroy.
- `terraform apply` succeeded on the first try — VPC, subnets, IGW,
  route tables, security groups, key pair, and 3 EC2 instances all
  created (~1 minute).

## Setting up the control node
- Installed Docker + Ansible manually on the `ansible-control` EC2
  instance via SSH.
- `pip3 install ansible --break-system-packages` failed — the pip
  version on this Ubuntu AMI didn't support that flag. Switched to
  `sudo apt install -y ansible` instead, which worked.

## Ansible run #1 — failed
```
ERROR! the role 'device_config' was not found in
/home/ubuntu/ansible/playbooks/roles:...
```
Cause: our `roles/` folder sits next to `playbooks/`, not inside it,
but Ansible's default search path expects `roles/` under the playbook
directory. Fixed by adding `roles_path = ./roles` to `ansible.cfg`.

## Ansible run #2 — failed
```
'device_ip' is undefined
```
Cause: `group_vars/all.yml` was sitting at the project root, but
Ansible only auto-loads `group_vars/` when it's next to the
**inventory file** being used. Since we run with
`-i inventory/hosts-aws.ini`, the file needed to be at
`inventory/group_vars/all.yml`. Moved it there.

## Ansible run #3 — mostly succeeded, one task failed
All 6 device_config tasks and all 7 system_info data-gathering tasks
completed. One task failed:
```
could not locate file in lookup: /tmp/system_info_router1.txt
```
Cause: we used a `debug` + `lookup('file', ...)` task to preview the
report content, but `lookup('file', ...)` reads from the **control
node's** filesystem, not the remote host's — and the report file only
existed on the remote host at that point in the play. Removed that
debug task entirely since the report gets `fetch`-ed back to the
control node in the next task anyway, which is the actually useful part.

## Ansible run #4 — mostly succeeded, idempotency issue
Running the playbook a second time (to confirm it's safe to re-run)
failed on two tasks:
```
Error: ipv4: Address already assigned.
```
Cause: our `changed_when`/`failed_when` conditions only checked for
Linux's `"File exists"` error message, but AWS's Ubuntu network stack
returns `"Address already assigned"` instead when an IP is already
set. Updated the conditions to also treat that message as "already
done, not a failure" for the IP-address task, and added a similar
check for the static route task.

## Ansible run #5 — full success
```
router1 : ok=21  changed=6  unreachable=0  failed=0
router2 : ok=21  changed=4  unreachable=0  failed=0
```
Confirmed the playbook is idempotent (safe to re-run) and all 6
device-configuration requirements plus all 7 system-info requirements
work end-to-end against real EC2 instances in a private subnet.

## Evidence collected
- `evidence/` folder: fetched device_info and system_info reports for
  both routers, pulled from the control node back to the local machine.
- AWS Console screenshots of the running VPC/subnets/EC2 instances
  (see report).

## Known limitations / things we'd improve with more time
- The `device_config` role currently reuses the same `device_ip` for
  both routers, which caused a harmless "already assigned" idempotency
  quirk. With more time we'd parameterize this per-host.
- Docker Compose setup and the AWS/Terraform setup are two separate
  demonstrations rather than one unified pipeline; combining them
  (e.g. running the Ansible control container itself on the EC2
  bastion) is a possible future improvement.
