from h import *
G = T.GROUP_ID
def grp(extra):
    base = dict(name="Tester", isInternalGroup=False, publicLinkEnabled=True, publicLinkLimitEnabled=True, publicLinkLimit=50)
    base.update(extra)
    return dict(data=[dict(id=G, attributes=base)])
class Pre(T.FakeLinkASC):
    def __init__(self, mode, **k):
        self.mode = mode
        super().__init__(**k)
    def read(self, path):
        route = path.partition("?")[0]
        m = self.mode
        bd = route.endswith("/buildBetaDetail")
        d = None
        if m == "build-no-id" and route == "/v1/builds":
            d = [dict(attributes=dict())]
        if m == "build-str" and route == "/v1/builds":
            d = ["x"]
        if m == "members-none" and route.endswith("/relationships/builds"):
            d = [None]
        if m == "detail-list" and bd:
            d = [1]
        if m == "detail-attrs-list" and bd:
            d = dict(attributes=["a"])
        if m == "detail-state-int" and bd:
            d = dict(attributes=dict(externalBuildState=5))
        if m == "detail-state-list" and bd:
            d = dict(attributes=dict(externalBuildState=["BETA_APPROVED"]))
        if m == "groups-dict" and route == "/v1/apps/APP1/betaGroups":
            d = dict(id=G)
        if m == "groups-str" and route == "/v1/apps/APP1/betaGroups":
            d = "x"
        if d is not None:
            return 200, dict(data=d)
        return super().read(path)
for m in ["build-no-id", "build-str", "members-none", "detail-list", "detail-attrs-list", "detail-state-int", "detail-state-list", "groups-dict", "groups-str"]:
    hdr("PRE " + m)
    run(Pre(m))
two = dict(data=grp(dict())["data"] + [dict(id="G2", attributes=dict(name="Tester", isInternalGroup=False))])
internal = dict(data=grp(dict())["data"] + [dict(id="G2", attributes=dict(name="Tester", isInternalGroup=True))])
cases = [("limit50.0", grp(dict(publicLinkLimit=50.0))), ("limit-str50", grp(dict(publicLinkLimit="50"))), ("limitTrue", grp(dict(publicLinkLimit=True))),
         ("limit51", grp(dict(publicLinkLimit=51))), ("limitEnabledFalse", grp(dict(publicLinkLimitEnabled=False))),
         ("enabled-str-true", grp(dict(publicLinkEnabled="true"))), ("enabled1", grp(dict(publicLinkEnabled=1))),
         ("two-external", two), ("internal-extra", internal), ("data-null", dict(data=None)), ("body-list", []), ("good", grp(dict()))]
for name, rb in cases:
    hdr("READBACK " + name)
    run(T.FakeLinkASC(malformed_readback=rb))
for name, kw in [("aus-enabled-missing", dict(enabled=T.MISSING)), ("aus-enabled-None", dict(enabled=None)), ("aus-on", dict(enabled=True))]:
    hdr(name)
    run(T.FakeLinkASC(**kw), "--aus")
