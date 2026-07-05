# SECR3253 Network Automation Group Project

## Overview
This project automates network device configuration and Linux system
information gathering using **Docker + Ansible**.

Since we don't have physical routers, we simulate 2 network devices
(`router1`, `router2`) as Linux containers reachable over SSH. Ansible
connects to them from a control-node container and performs all
required configuration and reporting tasks.

## Architecture
```
                 +-------------------+
                 |  ansible-control  |
                 |  (runs playbooks) |
                 +---------+---------+
                           | SSH
             +-------------+-------------+
             |                           |
      +------v------+           +--------v-----+
      |   router1    |           |   router2    |
      | (sim device) |           | (sim device) |
      +--------------+           +--------------+
```

## Tasks Automated
**Device configuration (per device):**
1. Configure IP address on interface
2. Create a user account
3. Configure login banner message
4. Set interface description (alias)
5. Add a static route
6. Retrieve device information (facts)

**System information collection:**
- Hostname
- Current date and time
- CPU information
- Memory usage
- Disk usage
- Logged-in users
- Top 5 processes by CPU usage

Reports are saved automatically to the `reports/` folder on the host
machine after each run.

## How to Run
1. Install Docker Desktop.
2. Clone this repo:
   ```
   git clone <your-repo-url>
   cd network-automation-project
   ```
3. Build and start the containers:
   ```
   docker compose up -d --build
   ```
4. Enter the Ansible control container:
   ```
   docker exec -it ansible-control bash
   ```
5. Test connectivity:
   ```
   cd /ansible
   ansible routers -m ping
   ```
6. Run the full automation:
   ```
   ansible-playbook playbooks/site.yml
   ```
7. Check results in the `reports/` folder (on your host machine, not
   inside the container) — you'll see one device-info and one
   system-info text file per device.

## Project Structure
```
network-automation-project/
├── docker-compose.yml
├── docker/
│   ├── control/Dockerfile      # Ansible control node image
│   └── device/Dockerfile       # Simulated network device image
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/hosts.ini
│   ├── group_vars/all.yml
│   ├── playbooks/site.yml
│   └── roles/
│       ├── device_config/      # Tasks 1-6
│       └── system_info/        # System info collection
└── reports/                    # Auto-generated output reports
```

## Team Task Division (suggested — edit to match your actual group)
| Member | Responsibility | Files owned |
|---|---|---|
| Member A | Docker environment setup | `docker-compose.yml`, `docker/` |
| Member B | Device configuration automation | `ansible/roles/device_config/` |
| Member C | System info automation | `ansible/roles/system_info/` |
| Member D | Inventory/vars, testing, README, integration | `ansible/inventory/`, `ansible/group_vars/`, `README.md` |

Each member should commit their own part directly, so the Git history
reflects real, individual contribution (this is 30% of your marks).

## Git Workflow (do this as a group)
```bash
# each member, on their own machine:
git clone <repo-url>
git checkout -b feature/<your-name>-<your-part>
# ... make your changes ...
git add .
git commit -m "Add device_config role: IP, user, banner tasks"
git push origin feature/<your-name>-<your-part>
# then open a Pull Request on GitHub and merge into main
```
Avoid one person pushing everything in a single commit — that will
look like no real collaboration happened.
