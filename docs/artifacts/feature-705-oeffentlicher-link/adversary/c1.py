from h import *
hdr("A: typo arg enables link")
f = T.FakeLinkASC()
run(f, "--AUS")
hdr("B: aus when publicLinkEnabled is string true")
f = T.FakeLinkASC()
f.group["attributes"]["publicLinkEnabled"] = "true"
run(f, "--aus")
