# 🛡️ AuditReaper v2.4  
**Automated Linux System Audit & Security Dashboard Tool**

---

## 📖 Description
AuditReaper is a lightweight, fully-automated **Linux auditing script** written in Bash.  
It collects important system and security information, organizes it into structured text and JSON files, and finally generates an **interactive HTML dashboard** to visualize findings.

It’s ideal for:
- System administrators verifying configurations
- Security auditors performing quick assessments
- Anyone who wants an overview of a Linux host’s posture

---

## ⚙️ Features
- 🧩 Modular audit engine (system, users, network, services, logs, credentials, etc.)
- 📦 Auto-install dependencies when missing (`--install-deps`)
- 🧱 JSON + TXT + HTML output
- 🧠 Redaction mode to hide passwords / keys
- 📊 Interactive dashboard (Chart.js)
- 🔍 Deep scan with integrity and rootkit checks
- ♻️ Dashboard rebuild from existing JSON (no rescan needed)
- 💡 Works on most Debian / Ubuntu / Kali systems

---

## 🧭 How It Works
1. **Collect** data from system configuration, network, users, services, etc.  
2. **Store** outputs in organized folders under `~/AuditReaper-Results/<host>_<timestamp>/`.  
3. **Summarize** all findings into structured JSON.  
4. **Render** a modern HTML dashboard with charts and categorized findings.

---

## 🧰 Installation
Clone the project and make it executable:
```bash
git clone https://github.com/pred07/AuditReaper.git
cd AuditReaper
chmod +x AuditReaper.sh
Optional: install dependencies in advance

bash
Copy code
sudo apt install -y jq curl awk sed grep find stat ss
🚀 Usage
Basic Audit
bash
Copy code
sudo ./AuditReaper.sh --yes
Full Deep Scan (includes rkhunter, chkrootkit, debsums)
bash
Copy code
sudo ./AuditReaper.sh --full --yes
Install Dependencies Automatically
bash
Copy code
sudo ./AuditReaper.sh --install-deps --yes
Custom Output Directory
bash
Copy code
sudo ./AuditReaper.sh --output-dir ~/MyAudits --yes
Skip Dashboard Generation
bash
Copy code
sudo ./AuditReaper.sh --no-html --yes
Redact Sensitive Data
bash
Copy code
sudo ./AuditReaper.sh --redact --yes
Verbose / Quiet Mode
bash
Copy code
sudo ./AuditReaper.sh -v        # Verbose
sudo ./AuditReaper.sh -q --yes  # Quiet
Display Help Menu
bash
Copy code
sudo ./AuditReaper.sh --help
🧩 Help Command Output
sql
Copy code
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
📂 Output Structure
pgsql
Copy code
AuditReaper-Results/
└── <host>_<timestamp>/
    ├── sections/               # Per-module audit results
    ├── data/
    │   ├── audit_results.json  # Summary data
    │   └── findings.json       # Findings list
    ├── auditreaper_*.txt       # Combined text report
    ├── audit_dashboard.html    # Visual dashboard
    └── errors.log              # Error log (if any)
📊 Viewing the Dashboard
Open the generated HTML file:

bash
Copy code
google-chrome --no-sandbox ~/AuditReaper-Results/<host>_<timestamp>/audit_dashboard.html
or

bash
Copy code
firefox ~/AuditReaper-Results/<host>_<timestamp>/audit_dashboard.html
If you are running as root, Chrome requires --no-sandbox.

♻️ Rebuild Dashboard (No Rescan Needed)
Use the included helper:

bash
Copy code
sudo ./rebuild_dashboard.sh
Or rebuild manually:

bash
Copy code
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
📦 Dependencies
AuditReaper checks for missing tools automatically.
If missing, you can install them with:

bash
Copy code
sudo ./AuditReaper.sh --install-deps --yes
Core: jq, curl, awk, grep, sed, find, stat, ss, hostname, date
Optional: debsums, docker, podman, rkhunter, chkrootkit, net-tools, libcap2-bin

🧠 Summary of Operation
Stage	Action
1	Collects audit data from the system
2	Saves section reports and JSON
3	Generates combined .txt report
4	Builds interactive HTML dashboard
5	Archives everything into .tar.gz

💡 Feedback & Improvements
Feel free to fork and improve AuditReaper.
Suggestions, fixes, or visual enhancements are always welcome.

For future improvements or modifications, please open an issue on the GitHub repository so ideas and fixes remain public and traceable by the community.

📜 License
MIT License © 2025
Developed by 0xbrijith
Enhanced dashboard and rebuild automation by GROOT4272

yaml
Copy code

---

✅ **Copy-paste this entire block into a new file named `README.md`** inside your `~/AuditReaper/` directory.  
It will render perfectly formatted on GitHub or GitLab.
