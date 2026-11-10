# Output reference

Each run creates `AuditReaper-Results/<short-hostname>_<timestamp>/` beside `AuditReaper.sh`. A compressed archive is written next to that directory.

```text
<host>_<timestamp>/
├── sections/                 # Individual module text reports
├── data/
│   ├── audit_results.json    # Run metadata and summary counts
│   └── findings.json         # Structured security findings
├── auditreaper_<host>_*.txt  # Combined text report
├── audit_dashboard.html      # Unless --no-html or generation fails
└── errors.log                # Captured errors and diagnostics
```

Section files cover system information, users/groups, network configuration, firewall, installed packages, services/processes, security-sensitive files, scheduled tasks, system logs, shell histories, containers, credential-pattern scan, recent file changes, and service versions. `--full` adds package-integrity and rootkit-check sections when the relevant tools are available.

Summary counts are script-generated indicators based on checks and findings. They require contextual review and are not a comprehensive vulnerability score.

## Dashboard regeneration

`generate_dashboard.sh <results-directory>` uses `dashboard_template.html` from the current working directory, reads `data/audit_results.json` and `data/findings.json` when present, and writes `audit_dashboard.html` in the results directory. Python 3 is required. The helper does not recollect host data.
