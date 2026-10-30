
from h import *
shapes = {'non-dict element': {'data': ['x']}, 'no id': {'data': [{'attributes': {'name':'Tester','isInternalGroup': False}}]}, 'attributes list': {'data': [{'id':'G','attributes': ['a']}]}, 'data null elements': {'data':[None]}}
for name, body in shapes.items():
    hdr('readback shape: ' + name)
    class F(T.FakeLinkASC):
        def read(self, path, body=body):
            if self.patched and path.split('?')[0] == '/v1/apps/APP1/betaGroups':
                return 200, body
            return super().read(path)
        def write(self, m, p, b):
            r = super().write(m, p, b)
            self.patched = True
            return r
    f = F(); run(f)
