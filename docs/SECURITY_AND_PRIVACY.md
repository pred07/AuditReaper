# Security and privacy notes

## Authorization and collection notice

Run AuditReaper only on systems you own or have explicit authorization to assess. Its interactive notice names sensitive collection areas, including system information, logs, shell histories, SSH authorized keys, network configuration, and installed packages. It does not enforce a separate consent workflow for non-interactive sessions: the current implementation disables the prompt when input is not interactive. `--yes` also skips the prompt. Establish authorization before unattended runs.

## Handling results

Reports and archives are stored locally. The repository code does not implement a report upload destination or automatic retention/deletion policy. Local outputs can expose sensitive information and must be protected accordingly.

## Redaction limits

`--redact` applies a small set of regex substitutions only at selected collection points, including shell histories, authorized-keys output, and credential-scan matches. It targets a few recognizable forms such as some AWS key IDs, private-key header lines, `password=`/`token=` values, long digit sequences, and 64-character hexadecimal strings. It does not scrub all report fields, JSON findings, errors, or arbitrary secret formats. Treat reports as sensitive even when redaction is enabled, and inspect them before sharing.

## Host changes and dashboard

Normal collection creates report files and an archive. `--install-deps` mutates the host by updating apt metadata and installing packages as root. Optional deep checks execute third-party tools; review their behavior for the environment. The HTML dashboard is generated locally; do not publish it unless its data is approved for disclosure.
