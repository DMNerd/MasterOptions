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


def load_master_options(lua, mo_path):
    """MasterOptions.lua and the files that follow it in the .toc (AddonSettings.lua ... Startup.lua), in that order,
    sharing one addon table as the game gives them (local _, ns = ...)."""
    d = os.path.dirname(os.path.abspath(mo_path))
    toc = open(os.path.join(d, "MasterOptions.toc"), encoding="utf-8").read().splitlines()
    files = [l.strip() for l in toc if l.strip() and not l.startswith("#")]
    start = files.index("MasterOptions.lua")
    core = []
    for f in files[start:]:
        if "\\" in f or "/" in f:
            break  # (Modules\... : the modules come after the core files)
        core.append(f)
    ns = lua.table()
    load = lua.eval("function(s, n) local f, e = load(s, '=' .. n); if not f then error(e) end; return f end")
    for f in core:
        load(open(os.path.join(d, f), encoding="utf-8").read(), f)("MasterOptions", ns)
    return ns
