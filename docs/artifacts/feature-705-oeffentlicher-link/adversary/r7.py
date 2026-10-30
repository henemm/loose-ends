from h import *
two = dict(data=[dict(id=T.GROUP_ID, attributes=dict(name="Tester", isInternalGroup=False, publicLinkEnabled=True)),
                 dict(id="G2", attributes=dict(name="Tester", isInternalGroup=False))])
class Dup(T.FakeLinkASC):
    def read(self, path):
        if path.partition("?")[0] == "/v1/apps/APP1/betaGroups":
            return 200, two
        return super().read(path)
hdr("aus-with-two-external-Tester")
run(Dup(enabled=True), "--aus")
hdr("typo arg")
run(T.FakeLinkASC(), "--on")
