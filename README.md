# SECR3253 Network Automation Group Project

Group project for Network Programming. Automates network device config
and collects Linux system info using Docker, Ansible, and Terraform
(AWS).

## What we built
We don't have real routers to play with, so we simulate 2 network
devices as Linux hosts reachable over SSH. Ansible connects to them
and handles:

**Device configuration (per device)**
1. Set IP address on the interface
2. Create a user account
3. Set a login banner
4. Set interface description (alias)
5. Add a static route
6. Pull back device info (facts)

**System info collection**
- hostname
- current date/time
- CPU info
- memory usage
- disk usage
- logged-in users
- top 5 processes by CPU usage

There's 2 ways to run this:
1. **Docker** — everything local in containers, quick to test
2. **Terraform + AWS** — real VPC (public + private subnet) deployed
   on AWS, this is the version we actually used for testing/demo

## Option 1: Docker (local)
```bash
docker compose up -d --build
docker exec -it ansible-control bash
cd /ansible
ansible routers -m ping
ansible-playbook playbooks/site.yml
```
Output goes to `reports/`.

## Option 2: Terraform + AWS (what we actually deployed)
Full steps in `TERRAFORM_SETUP.md`. Quick version:
```bash
cd terraform
terraform init
terraform apply
```
Then SSH into the control node, install Ansible, copy the `ansible/`
folder over, and run the playbook against router1/router2 in the
private subnet. We hit a few bugs getting this working — all written
up in `PROJECT_LOG.md` with the actual errors and how we fixed them.

## Project structure
```
network-automation-project/
├── docker-compose.yml
├── docker/                     # Docker version (control + device images)
├── terraform/                  # Terraform - VPC, subnets, EC2 (main deployment)
├── aws/                        # older AWS CLI scripts, not used in final version
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/               # hosts.ini (Docker) + hosts-aws.ini (AWS)
│   ├── playbooks/site.yml
│   └── roles/
│       ├── device_config/       # tasks 1-6
│       └── system_info/         # system info collection
├── evidence/                    # output from our actual AWS run
├── PROJECT_LOG.md               # bugs we hit + fixes
├── TERRAFORM_SETUP.md
├── AWS_SETUP.md                 # old CLI version, kept for reference
└── REFLECTION_TEMPLATE.md
```

## Team
| Name | Part |
|---|---|
| NORMAN SHANE NYIGOR SX170149CSRS04| Docker setup |
| MOHAMMAD MUSLIM BIN CHE ISMAIL SX190866CSRS04| device_config role |
| MUHAMMAD AZMI BIN HAMIDI SX231768ECRHF04| system_info role |
| MUHAMAD DZARHAN BIN AZMY SX240663ECRHS04| Terraform + AWS deployment |

## Other docs in this repo
- `TERRAFORM_SETUP.md` — how we deployed on AWS (main version)
- `AWS_SETUP.md` — earlier AWS CLI version, single public subnet only, kept as backup
- `PROJECT_LOG.md` — errors we ran into and how we fixed them
- `REFLECTION_TEMPLATE.md` — template each member fills in individually
