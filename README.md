# AuditReaper v2.5  
**Automated Linux System Audit & Security Dashboard**

---

## ⚡ Quick Start
Run everything in one go:
```bash
sudo ./AuditReaper.sh --install-deps --full --yes
```
This installs missing dependencies, runs a deep audit, and generates an interactive HTML dashboard.

---

## 📖 Description
AuditReaper is a lightweight automated **Linux auditing framework** that collects critical system, security, and configuration data.  
It outputs clean text and JSON reports, and builds an **interactive HTML dashboard** for visualizing results — all with a single command.

---

## 🧰 Installation
Clone and make executable:
```bash
git clone https://github.com/pred07/AuditReaper.git
cd AuditReaper
chmod +x AuditReaper.sh
```
Optional dependency install:
```bash
sudo apt install -y jq curl awk sed grep find stat ss
```

---

## 🚀 Usage

### 🔹 Basic Audit
```bash
sudo ./AuditReaper.sh --yes
```

### 🔹 Full Deep Scan (with integrity & rootkit checks)
```bash
sudo ./AuditReaper.sh --full --yes
```

### 🔹 Install Dependencies Automatically
```bash
sudo ./AuditReaper.sh --install-deps --yes
```

### 🔹 Custom Output Directory
```bash
sudo ./AuditReaper.sh --output-dir ~/MyAudits --yes
```

### 🔹 Skip Dashboard Generation
```bash
sudo ./AuditReaper.sh --no-html --yes
```

### 🔹 Redact Sensitive Data
```bash
sudo ./AuditReaper.sh --redact --yes
```

### 🔹 Verbose / Quiet Mode
```bash
sudo ./AuditReaper.sh -v        # Verbose
sudo ./AuditReaper.sh -q --yes  # Quiet
```

### 🔹 Display Help Menu
```bash
sudo ./AuditReaper.sh --help
```

---

## 🧩 Help Command Output
```
============================================================
  AuditReaper v2.4
  Author: 0xbrijith | https://github.com/pred07/AuditReaper
============================================================

USAGE:
  sudo ./AuditReaper.sh [OPTIONS]

OPTIONS:
  --install-deps       Install dependencies (apt)
  --yes                Skip consent prompt (non-interactive)
  --full               Run deep scan (debsums, rkhunter, chkrootkit)
  --redact             Redact sensitive data in outputs
  --no-html            Skip HTML dashboard generation
  --output-dir DIR     Save results to custom directory
  -v                   Verbose mode
  -q                   Quiet mode
  -h, --help           Show this help menu

EXAMPLES:
  sudo ./AuditReaper.sh --install-deps --yes
  sudo ./AuditReaper.sh --full --yes --output-dir ~/AuditReaper-Results
```

---

## 📂 Output Structure
```
AuditReaper-Results/
└── <host>_<timestamp>/
    ├── sections/               # Per-module audit results
    ├── data/
    │   ├── audit_results.json  # Summary data
    │   └── findings.json       # Findings list
    ├── auditreaper_*.txt       # Combined text report
    ├── audit_dashboard.html    # Visual dashboard
    └── errors.log              # Error log (if any)
```

---

## 📊 Viewing the Dashboard
```bash
google-chrome --no-sandbox ~/AuditReaper-Results/<host>_<timestamp>/audit_dashboard.html
```
or
```bash
firefox ~/AuditReaper-Results/<host>_<timestamp>/audit_dashboard.html
```
> ⚠️ When running as **root**, Chrome requires the `--no-sandbox` flag.

---

## ♻️ Rebuild Dashboard (No Rescan Needed)
Use helper script:
```bash
sudo ./rebuild_dashboard.sh
```
Or rebuild manually:
```bash
cd ~/AuditReaper-Results/<host>_<timestamp>
template=~/AuditReaper/dashboard_template.html
audit_json=data/audit_results.json
findings_json=data/findings.json
out_html=~/AuditReports/audit_dashboard.html

mkdir -p ~/AuditReports
json_data=$(jq -c . "$audit_json")
findings_data=$(jq -c . "$findings_json")

cp "$template" "$out_html"
sed -i "s|{{AUDIT_DATA}}|$json_data|g" "$out_html"
sed -i "s|{{FINDINGS_DATA}}|$findings_data|g" "$out_html"

google-chrome --no-sandbox "$out_html"
```

---

## 📦 Dependencies
AuditReaper will install missing dependencies automatically when you run:
```bash
sudo ./AuditReaper.sh --install-deps --yes
```

**Core Packages:**  
`jq`, `curl`, `awk`, `grep`, `sed`, `find`, `stat`, `ss`, `hostname`, `date`

**Optional Tools:**  
`debsums`, `docker`, `podman`, `rkhunter`, `chkrootkit`, `net-tools`, `libcap2-bin`

---

## 🧠 Summary of Operation
| Stage | Action |
|-------|---------|
| 1 | Collects audit data from the system |
| 2 | Saves section reports and JSON |
| 3 | Generates combined `.txt` report |
| 4 | Builds interactive HTML dashboard |
| 5 | Archives everything into `.tar.gz` |

---

## 💡 Feedback & Improvements
AuditReaper is open for improvement — feel free to **fork, modify, and enhance** it.  
Suggestions, bug reports, and dashboard feature ideas are welcome.  
Please open issues or pull requests on the repository to keep all updates transparent.

---

## 📜 License
MIT License © 2025  
Developed by **0xbrijith**  
