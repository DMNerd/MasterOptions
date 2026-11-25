import os, sys, glob
from lupa import LuaRuntime
lua = LuaRuntime()
chk = lua.eval("function(s, n) local f, e = load(s, '=' .. n); return e or 'OK' end")
for p in sorted(glob.glob(sys.argv[1] + "/*.lua")):
    print(os.path.basename(p), chk(open(p, encoding="utf-8").read(), p))
