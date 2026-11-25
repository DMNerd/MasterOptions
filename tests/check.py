import sys
from lupa import LuaRuntime
lua = LuaRuntime()
src = open(sys.argv[1], encoding="utf-8").read()
f = lua.eval("function(s) local f, e = load(s, '=MasterOptions.lua'); return e or 'OK' end")
print(f(src))
