# Shared.lua (MasterOptions_Shared) is loaded before MasterOptions.lua and the modules in game (.toc): tests that
# load one of those files on its own load it first, from the addon folder the tested file is in.
import os


def load_shared(lua, tested_path):
    d = os.path.dirname(os.path.abspath(tested_path))
    for _ in range(3):
        p = os.path.join(d, "Shared.lua")
        if os.path.exists(p):
            f = lua.eval("function(s) local f, e = load(s, '=Shared.lua'); if not f then error(e) end; return f end")
            f(open(p, encoding="utf-8").read())()
            return
        d = os.path.dirname(d)
    raise FileNotFoundError("Shared.lua not found above " + tested_path)
