# Data inventory

AuditReaper writes data locally under `AuditReaper-Results/<host>_<timestamp>/`, then creates a compressed archive beside that directory. Collection runs on the audited host.

| Area | Examples |
| --- | --- |
| Host and OS | Hostname, kernel, platform details |
| Accounts | User and group information |
| Network and firewall | Interface/configuration details, listening sockets, firewall rules |
| Software and runtime | Installed packages, services, processes, selected service versions |
| Sensitive filesystem state | SUID/SGID and capability-related findings, world-writable paths in selected locations |
| Persistence and activity | Scheduled tasks, recent system logs and logins, recent changes under selected directories |
| User files | Up to the last 100 lines of readable shell histories; up to the first 50 lines of readable `authorized_keys` files |
| Containers | Docker/Podman information when available |
| Credential-pattern scan | Matching lines from configured searches under `/home`, `/root`, `/etc`, and `/opt`, bounded by script time and line limits |
| Deep checks | Optional package-integrity and rootkit-check tool output |

Exact fields depend on permissions, installed commands, and OS layout. Outputs include per-section text, a combined report, JSON summary/findings, optional HTML dashboard, error log, and archive.

Treat all outputs as sensitive. They may reveal usernames, internal addresses, software inventory, file paths, operational activity, and secret-like values. Use restrictive permissions, approved transfer channels, and the organization’s retention policy.
