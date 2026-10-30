from h import *
import time, signal
class Slow(T.FakeLinkASC):
    def read(self, path):
        if self.patched and path.partition("?")[0] == "/v1/apps/APP1/betaGroups":
            time.sleep(8)
        return super().read(path)
f = Slow()
e = dict(os.environ, ASC_POLL_SECONDS="0", ASC_TIMEOUT_SECONDS="30", ASC_PLATFORM="", ASC_API_BASE=f.base)
e["ASC_KEY_ID"] = "K"
e["ASC_ISSUER_ID"] = "I"
e["ASC_KEY_FILE"] = str(case.key)
p = subprocess.Popen([sys.executable, W + "/scripts/asc_beta_link.py"], env=e, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=W + "/scripts")
time.sleep(4)
print("patches before signal", f.patches())
p.send_signal(signal.SIGINT)
o, er = p.communicate(timeout=60)
print("EXIT", p.returncode)
print("OUT", o)
print("ERR", er)
print("PATCHES", f.patches(), "final", f.group["attributes"])
hdr("on-wrong-limit-notready")
class W2(T.FakeLinkASC):
    pass
g = T.FakeLinkASC(enabled=True, extern=dict())
g.group["attributes"]["publicLinkLimitEnabled"] = False
g.extern = dict((b["id"], "IN_BETA_TESTING") for b in T.BUILDS.values())
run(g)
