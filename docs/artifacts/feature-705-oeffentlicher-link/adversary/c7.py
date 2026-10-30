from h import *
f = T.FakeLinkASC()
f.extern[T.BUILDS["IOS"]["id"]] = "PROCESSING"
f.group["attributes"].update(publicLinkEnabled=True, publicLinkLimitEnabled=True, publicLinkLimit=10000)
run(f)
