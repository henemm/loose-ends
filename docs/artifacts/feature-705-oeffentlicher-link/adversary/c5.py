from h import *
f = T.FakeLinkASC()
f.group["attributes"]["publicLinkEnabled"] = True
f.fail_patch = (422, "Y")
run(f, "--aus")
