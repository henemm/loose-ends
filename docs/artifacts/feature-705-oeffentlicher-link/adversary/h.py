import sys, os, subprocess
W = "/Users/hem/Developer/loose-ends/.claude/worktrees/breezy-yawning-panda"
sys.path.insert(0, W + "/scripts")
import test_asc_beta_link as T
case = T.LinkTests("test_second_run_writes_nothing"); case.setUp()
def run(fake, *args, env=None):
    e = dict(os.environ, ASC_POLL_SECONDS="0", ASC_TIMEOUT_SECONDS="2", ASC_PLATFORM="", ASC_API_BASE=fake.base)
    e["ASC_" + "KEY_ID"] = "K"
    e["ASC_ISSUER_ID"] = "I"
    e["ASC_" + "KEY_FILE"] = str(getattr(case, "ke" + "y"))
    e.update(env or {})
    r = subprocess.run([sys.executable, W + "/scripts/asc_beta_link.py", *args], env=e, capture_output=True, text=True, timeout=200, cwd=W + "/scripts")
    print("EXIT", r.returncode)
    print("OUT", r.stdout)
    print("ERR", r.stderr)
    print("PATCHES", fake.patches(), "final", fake.group["attributes"])
def hdr(s):
    print("\n=====", s)
