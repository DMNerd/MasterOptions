# The options' module list (Options.lua MODULES) against the modules themselves: every module in the .toc has a
# row (until 2.9.0 seven had none: the list was a fixed one, not kept up), with the same needs its
# MasterOptions_Module line declares (its row is greyed while one isn't loaded), and an explanation (PATCH_TIP).
import os, re, sys

options = sys.argv[1]
root = os.path.dirname(options)
src = open(options, encoding="utf-8").read()
toc = open(os.path.join(root, "MasterOptions.toc"), encoding="utf-8").read()

def names(text):
    return re.findall(r'"([^"]+)"', text)

listed, tips = {}, set()
block = src[src.index("local MODULES = {"):src.index("local NICE = {")]
for m in re.finditer(r'\{\s*"([A-Za-z_]+)",\s*"[^"]*",\s*\{([^}]*)\}(,\s*since = \d+,\s*tip = ")?', block):
    listed[m.group(1)] = names(m.group(2))
    if m.group(3): tips.add(m.group(1))

in_toc = re.findall(r'^Modules\\([A-Za-z_]+)\.lua\s*$', toc, re.M)
declared = {}
for name in in_toc:
    text = open(os.path.join(root, "Modules", name + ".lua"), encoding="utf-8").read()
    m = re.search(r'MasterOptions_Module\("([^"]+)",\s*\{([^}]*)\}', text)
    declared[m.group(1)] = names(m.group(2))

files = sorted(f[:-4] for f in os.listdir(os.path.join(root, "Modules")) if f.endswith(".lua"))
res = {
    "every module file is in the .toc": sorted(in_toc) == files,
    "every module has a row in the options": set(declared) <= set(listed),
    "no row for a module that doesn't exist": set(listed) <= set(declared),
    "each row's needs are the ones its module declares": all(listed.get(k) == v for k, v in declared.items()),
    "each module has its since and an explanation (tip)": set(declared) <= tips,
}
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
missing = sorted(set(declared) - set(listed))
if missing: print("  without a row:", ", ".join(missing))
wrong = sorted(k for k, v in declared.items() if k in listed and listed[k] != v)
if wrong: print("  needs differ:", ", ".join(wrong))
untipped = sorted(set(declared) - tips)
if untipped: print("  no explanation:", ", ".join(untipped))
print("ERRORS:", sum(1 for v in res.values() if not v))
