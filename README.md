# Azure Server Hardening — Terraform + Ansible + CI/CD

A DevSecOps portfolio project provisioning a load-balanced, two-tier Azure infrastructure with Terraform, deployed through a GitHub Actions CI/CD pipeline, and configured post-deployment with Ansible.

**Repo:** [github.com/cwi1932/terraform-azure-Server_hardening_Ubuntu](https://github.com/cwi1932/terraform-azure-Server_hardening_Ubuntu)

## Architecture

- **Resource Group:** `server_hardening_RG1`
- **Networking:** Virtual Network with 3 subnets (backend tier, and reserved subnets for future frontend/database tiers), Network Security Group with scoped inbound rules
- **Compute:** 2 Ubuntu 24.04 LTS virtual machines (`backendA`, `backendB`), load-balanced via an Azure Load Balancer with health probes and NAT rules
- **Database:** Azure SQL Database (PaaS), with an Azure AD administrator and a system-assigned managed identity
- **Secrets:** Azure Key Vault storing the SQL admin password (generated via Terraform's `random_password`), with RBAC role assignments (Key Vault Secrets Officer / Secrets User) scoped to the VMs' and pipeline's managed identities
- **DNS:** A private DNS zone linked to the VNet with auto-registration enabled, so VMs resolve each other by hostname without manual DNS entries

This combines **IaaS** (the VMs, which are fully managed by the team) with **PaaS** (the SQL Database, which Azure manages) — a common real-world hybrid pattern, not a design compromise.

## CI/CD Pipeline (GitHub Actions)

Two jobs, connected via job outputs:

1. **`terraform`** — checkout → TFLint → Gitleaks (secret scanning) → `terraform fmt/init/validate/plan/apply` → captures VM private IPs as job outputs
2. **`ansible`** — receives the IPs from the `terraform` job, generates the Ansible inventory file, and uploads it as a downloadable build artifact (so it survives after the ephemeral GitHub runner shuts down)

Security gates:
- **TFLint** validates Terraform code style and catches misconfigurations before anything is provisioned
- **Gitleaks** scans the full commit history for accidentally-committed secrets on every push/PR
- **Terraform Apply** only runs on a push to `main` — pull requests only get a `plan`, so nothing is provisioned until a change is actually merged

Authentication uses a dedicated Azure service principal with client-secret credentials, scoped with least-privilege role assignments (`Contributor` at the subscription level, plus targeted `Storage Blob Data Contributor` and `Key Vault Secrets Officer` roles).

## Configuration Management (Ansible)

Once infrastructure is live, `Ansible/configuration_management.yml` runs against both backend VMs:

- Gathers OS release, CPU, and memory usage; conditionally reboots a VM if CPU or memory usage exceeds 80%
- Installs and enables Nginx
- Configures UFW as a host-level firewall:
  - Allows SSH only from a specific administrator IP
  - Allows HTTP/HTTPS from that same IP
  - Explicitly **denies lateral SSH movement** between the two backend VMs (defense in depth — even if one VM is compromised, it can't SSH into the other)
- Applies OS patch updates (`apt update && dist-upgrade`)

## Key engineering problems solved

- **Terraform dependency cycle** between the SQL server, its Key Vault secret, and the role assignment granting SQL access to that secret — resolved by removing an unnecessary `depends_on` and letting Terraform's implicit dependency graph handle ordering correctly
- **Regional capacity/availability constraints** — Azure SQL provisioning was restricted in the original region; the SQL server was pinned to a separate, available region while the rest of the stack stayed put
- **Load Balancer SNAT conflict** — a load balancing rule and an outbound rule both referenced the same frontend IP; fixed by explicitly disabling outbound SNAT on the load balancing rule
- **CI/CD backend authentication** — the Terraform Azure backend defaulted to interactive Azure CLI login, which has no session on an automated runner; fixed by granting the pipeline's service principal explicit RBAC roles instead
- **Git branch drift** — `main` and `dev` diverged in both commit history and file structure (nested vs. flattened folders) over the course of the project; resolved through careful branch comparison (`git log A..B`, `git diff --stat`) rather than blind force-pushes, with a verified backup branch as a safety net before any destructive operation

## Cost management

Infrastructure was provisioned and torn down (`terraform destroy` / resource group deletion) between testing sessions to control Pay-As-You-Go spend, using Azure Cost Analysis and `az consumption usage list` to verify no resources were left running unexpectedly.

## Verified run evidence

- **Terraform Apply:** `Apply complete! Resources: 36 added, 0 changed, 0 destroyed.` — full stack (VNet, subnets, NSG, Load Balancer, 2 VMs, Azure SQL, Key Vault, RBAC, private DNS) provisioned cleanly in a single pipeline run
- **Ansible Inventory artifact:** generated from Terraform's job outputs and uploaded as a downloadable pipeline artifact (`ansible-inventory.zip`, 178 bytes), solving the "ephemeral runner" problem so the inventory survives after the job ends
- **Ansible Playbook run:** `ansible-playbook -i ansible.ini configuration_management.yml` completed with zero failures —
  - `backendA: ok=16 changed=7 unreachable=0 failed=0`
  - `backendB: ok=15 changed=6 unreachable=0 failed=0 skipped=1`
  - (backendB's single "skipped" task was the conditional reboot — correctly skipped because its CPU/memory usage was under the 80% threshold)
- **Manual SSH verification:** confirmed direct key-based access to both VMs (`ssh -i backend_key.pem adminuser@<public-ip>`) independent of Ansible, to validate the NSG rule and key pairing before automating

## Tech stack

`Terraform` · `Azure` (VMs, Load Balancer, SQL Database, Key Vault, VNet, Private DNS) · `GitHub Actions` · `TFLint` · `Gitleaks` · `Ansible` · `UFW`
