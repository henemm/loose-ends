
from h import *
for val in [True, False, 'false', 'true', 0, 1, None, 'MISSING']:
    hdr('--aus enabled=%r' % (val,))
    f = T.FakeLinkASC(enabled=T.MISSING if val=='MISSING' else val)
    run(f, '--aus')
for a in (['--aus=1'],['-aus'],[''],['--aus','--aus'],['--aus '],['--aus','x'],['--AUS']):
    hdr('args %r' % (a,))
    f = T.FakeLinkASC(); run(f, *a); print('REQS', len(f.requests))
for st in (403,422,500,503):
    hdr('switch-off fail %d after mismatch' % st)
    class F(T.FakeLinkASC):
        def write(self, m, p, b, st=st):
            if b['data']['attributes'].get('publicLinkEnabled') is False: return st, {}
            return super().write(m, p, b)
    f=F(ignore_limit=True); run(f)
for st in (403,500):
    hdr('--aus patch %d' % st)
    class G(T.FakeLinkASC):
        def write(self,m,p,b,st=st): return st,{}
    f=G(enabled=True); run(f,'--aus')
