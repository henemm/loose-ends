"""Gate-Prüfung des installierten Plugins für den Wegwerf-Workflow probe-145.

Aufruf: python3 gate_probe.py <wegwerf-kopie>
"""
import os
import subprocess
import sys

os.chdir(sys.argv[1])
os.environ.pop("CLAUDE_PROJECT_DIR", None)
sys.path.insert(0, "/Users/hem/.claude/plugins/cache/henemm-private/agent-os-openspec/3.42.0/core/hooks")
import config_loader  # noqa: E402
import adversary_dialog as ad  # noqa: E402
import evidence_gate as eg  # noqa: E402

base = subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
data = {"name": "probe-145", "base_commit": base}
print("Plugin:", eg.__file__)
print("Config:", config_loader.find_config_file(config_loader.find_project_root()))
print("Basis:", base)
files, info = ad.phase8_code_files(data)
print("Änderungsmenge:", [ad.display_path(f) for f in files], "|", info)
print("Gate-Ergebnis:", eg.check_evidence("phase8_complete", data) or "None (durchgelassen)")
