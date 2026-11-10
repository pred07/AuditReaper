# Operations guide

## Prepare

1. Confirm authorization and host scope.
2. Review [data inventory](DATA_INVENTORY.md), including shell history, authorized keys, and credential-pattern scanning.
3. Confirm disk space and protect the output location. The script writes beneath its repository directory in `AuditReaper-Results`.
4. Confirm required commands are available. `--install-deps` updates apt metadata and installs a package list; use it only where host changes are approved.

## Run

Interactive run with consent prompt:

```bash
sudo ./AuditReaper.sh
```

Deep checks with limited redaction enabled:

```bash
sudo ./AuditReaper.sh --full --redact
```

For unattended authorized collection, `--yes` bypasses the prompt. Non-interactive execution also skips it, so approval must be established outside the script before automation.

## Review and share

- Confirm the expected host/timestamp directory and archive exist.
- Review `errors.log` and each section for missing tools or permission limits.
- Treat reports and archives as sensitive, including when `--redact` was used.
- Inspect for secrets, personal information, internal topology, and unrelated user data before sharing.

## Rebuild dashboard

Run from the repository root so the template path resolves:

```bash
./generate_dashboard.sh ./AuditReaper-Results/<host>_<timestamp>
```

The helper reads the existing JSON files and writes `audit_dashboard.html`; it does not run another audit.

Supported options: `--install-deps`, `--yes`, `--full`, `--redact`, `--no-html`, `-v`, `-q`, `-h`/`--help`. There is no custom output-path option in the current CLI.
