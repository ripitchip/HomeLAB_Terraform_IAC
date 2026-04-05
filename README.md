# HomeLAB_Terraform_IAC

IaC infrastructure (Terraform/Proxmox) designed for full autonomy and Air-Gapped operations.

### Strategic Pillars
* Local Autonomy: Internal application repositories (`apt`, `reg`) and resolution (`dns`) to eliminate internet dependency.
* Relay Architecture: Centralized flows via dedicated proxies (`ldap`, `auth`, `proxy`) for control and security.
* Decoupling: Stateless compute on Proxmox / Persistence on TrueNAS (NFS).

### Relay Architecture
1. Naming Relay (`dns`): Authoritative `.lan` resolution.
2. Identity Relay (`ldap` / `auth`): Centralized offline authentication.
3. Provisioning Relay (`apt` / `reg`): Local mirrors for WAN-less deployments.
4. Exposure Relay (`proxy`): Single entry point (Traefik) for all services.