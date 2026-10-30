from h import *
hdr("C: limit float/string/bool already on")
for v in (50.0, "50", True):
    f = T.FakeLinkASC()
    f.group["attributes"].update(publicLinkEnabled=True, publicLinkLimitEnabled=True, publicLinkLimit=v)
    run(f)
