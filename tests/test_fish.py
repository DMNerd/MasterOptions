import sys
from lupa import LuaRuntime

lua = LuaRuntime()

lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")  # (module files: run at once, as their old addon did)
lua.execute(r'''
NOW = 100
function GetTime() return NOW end
local function Frame(name, shown)
  local f = { name = name, shown = shown, ignore = false, alpha = 1, scripts = {} }
  function f:IsShown() return self.shown end
  function f:IsIgnoringParentAlpha() return self.ignore end
  function f:SetIgnoreParentAlpha(v) self.ignore = v end
  function f:GetAlpha() return self.alpha end
  function f:SetAlpha(v) self.alpha = v end
  function f:SetScript(k, fn) self.scripts[k] = fn end
  function f:GetScript(k) return self.scripts[k] end
  function f:RegisterEvent() end
  return f
end
MADE = {}
function CreateFrame() local f = Frame("anon", true); MADE[#MADE+1] = f; return f end
function Tick() for _, f in ipairs(MADE) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.3) end end end
function hooksecurefunc(t, k, fn) local o = t[k]; t[k] = function(...) o(...); fn(...) end end
UIParent = Frame("UIParent", true)
Baganator = { API = { Skins = { GetCurrentSkin = function() return "blizzard" end } } }
Baganator_SingleViewBackpackViewFrameblizzard = Frame("bags", true)
DCIFrame = Frame("DCI", true)
StaticPopup1 = Frame("popup", false)
CHAT = Frame("chat window", true); CHAT.ignore = true; CHAT.ScrollingMessages = {}
ChattynatorHyperlinkHandler = { GetChildren = function() return CHAT end }
MastercraftDB = { settings = { fishHideChat = "hide" } }
function State() return ("bags %s | DCI %s | popup %s | chat alpha %s"):format(tostring(Baganator_SingleViewBackpackViewFrameblizzard.ignore), tostring(DCIFrame.ignore), tostring(StaticPopup1.ignore), tostring(CHAT.alpha)) end
''')
lua.eval("function(s) return load(s, '=fish') end")(open(sys.argv[1], encoding="utf-8").read())()
L = lua.execute
print("before fishing:      ", lua.eval("State()"))
L("UIParent:SetAlpha(0); Tick()")
print("UI hidden (hide chat):", lua.eval("State()"))
L("StaticPopup1.shown = true; Tick()")
print("a popup opens:       ", lua.eval("State()"))
L("UIParent:SetAlpha(1)")
print("fishing view ends:   ", lua.eval("State()"))
L('MastercraftDB.settings.fishHideChat = "show"; UIParent:SetAlpha(0); Tick()')
print("UI hidden (show chat):", lua.eval("State()"))
L("UIParent:SetAlpha(1)")
