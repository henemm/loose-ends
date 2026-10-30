
from h import *
class A(T.FakeLinkASC):
    def write(self,m,p,b): return 403,{}
class B(T.FakeLinkASC):
    def write(self,m,p,b):
        r=super().write(m,p,b); self.patched=True
        return (500,{}) if b["data"]["attributes"].get("publicLinkEnabled") is True else r
for name,f,args in [("enable403",A(),()),("enable403-link-on",A(enabled=True),()),("enable500-applied",B(),()),("enable500-and-readback-500",B(break_reads_after_patch=True),()),("mismatch",T.FakeLinkASC(ignore_limit=True),()),("on-wrong-limit-notready",T.FakeLinkASC(enabled=True,extern={}),())]:
    hdr(name); run(f,*args)
print("LEAK tokens:", T.LINK, T.GROUP_ID, {k:v for k,v in T.BUILDS.items()})
