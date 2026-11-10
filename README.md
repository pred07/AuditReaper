# AuditReaper

AuditReaper is a Bash-based Linux system audit collector. It gathers host, account, network, firewall, package, service, filesystem, scheduled-task, log, shell-history, container, credential-pattern, and recent-file-change information into timestamped local reports. Optional deep mode invokes package-integrity and rootkit-checking utilities. It can generate a local HTML dashboard.

Use it only on systems you own or are authorized to assess. Review [data inventory](docs/DATA_INVENTORY.md) and [security and privacy notes](docs/SECURITY_AND_PRIVACY.md) first: reports can contain sensitive host details, user activity, and credential-like strings.

## Requirements

- Linux with Bash and `jq`, `curl`, `ss`, `awk`, `sed`, `grep`, `find`, `stat`, `uname`, `date`, and `hostname`.
- Root access is recommended for complete system visibility.
- `python3` is needed for the dashboard. `--install-deps` uses apt/apt-get, updates package metadata, and installs packages.
- Optional tools include `debsums`, `docker`, `podman`, `rkhunter`, `chkrootkit`, `netstat`, `getcap`, and `lsb_release`.

## Quick start

```bash
git clone https://github.com/pred07/AuditReaper.git
cd AuditReaper
chmod +x AuditReaper.sh
sudo ./AuditReaper.sh
```

The script displays a consent notice and asks before collection. In non-interactive execution, the prompt is disabled by the implementation; use `--yes` only when collection is authorized and the output location is understood.

## Options

```text
--install-deps  Update apt metadata and install the script's package list (root required)
--yes           Skip the interactive consent prompt
--full          Run additional package-integrity and rootkit checks
--redact        Apply limited substitutions to selected collected text
--no-html       Skip dashboard generation
-v              Verbose mode
-q              Quiet mode
-h, --help      Show help
```

Example:

```bash
sudo ./AuditReaper.sh --full --redact
```

The current CLI does not implement a custom output-directory option. Results are written under `AuditReaper-Results/<host>_<timestamp>/` beside the script, with a `.tar.gz` archive alongside. See [operations](docs/OPERATIONS.md) and [output reference](docs/OUTPUT_REFERENCE.md).

## Rebuild the dashboard

From the repository directory, pass the existing results directory to the supplied helper:

```bash
./generate_dashboard.sh ./AuditReaper-Results/<host>_<timestamp>
```

The helper expects `dashboard_template.html` in the current working directory and writes `audit_dashboard.html` into the selected results directory.

## Documentation

- [Operations guide](docs/OPERATIONS.md)
- [Data inventory](docs/DATA_INVENTORY.md)
- [Output reference](docs/OUTPUT_REFERENCE.md)
- [Security and privacy](docs/SECURITY_AND_PRIVACY.md)

## Project status

This repository provides shell scripts and a dashboard template. Review the implementation and run it in a controlled environment before relying on findings. There is no automated test suite or CI workflow in the repository. Findings are indicators for human review, not certification or proof of compromise.
