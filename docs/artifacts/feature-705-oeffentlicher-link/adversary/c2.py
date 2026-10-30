from h import *
hdr("D: second (off) PATCH fails after mismatch")
class F(T.FakeLinkASC):
    def write(self, m, p, b):
        if b["data"]["attributes"].get("publicLinkEnabled") is False:
            return 403, {}
        return super().write(m, p, b)
f = F(ignore_limit=True)
run(f)
hdr("I: 5xx on off patch after mismatch")
class F5(T.FakeLinkASC):
    def write(self, m, p, b):
        if b["data"]["attributes"].get("publicLinkEnabled") is False:
            return 500, {}
        return super().write(m, p, b)
f = F5(ignore_limit=True)
run(f)
