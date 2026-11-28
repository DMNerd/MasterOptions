# Questie_Chattynator: shift-clicking a Questie quest link in Chattynator's chat puts Questie's fresh link in the chat
# box in place of the one the game put in - what you typed around it stays; nothing else is touched.
import sys
src = open(sys.argv[1], encoding="utf-8").read()
import os as _os; sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import module_test; lua = module_test(sys.argv[1])
from shared_lua import fake_frames; fake_frames(lua, timers_now=True)
lua.execute(r'''
  strsplit = function(sep, s) local out = {} for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end return unpack(out) end
  unpack = unpack or table.unpack
  SHIFT = true
  function IsShiftKeyDown() return SHIFT end
  BOX = { text = "" }
  function BOX:GetText() return self.text end
  function BOX:SetText(t) self.text = t end
  function ChatEdit_GetActiveWindow() return BOX end
  function ChatEdit_InsertLink(l) BOX.text = BOX.text .. l end
  ChatFrameMixin = { OnHyperlinkClick = function() end } -- (the client where Questie hooks ChatFrame1..N only)
  Questie = { started = true }
  QuestieLoader = { ImportModule = function(_, name) if name == "QuestieLink" then return {
    GetQuestLinkStringById = function(id) return "|cffffff00|Hquestie:" .. id .. ":0|h[[30] The Fresh Title]|h|r" end } end end }
  HANDLER = { scripts = {} }
  function HANDLER:HookScript(k, fn) self.scripts[k] = fn end
  Chattynator = { API = { GetHyperlinkHandler = function() return HANDLER end } }
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_Questie_Chattynator")
L, E = lua.execute, lua.eval
L('Fire("PLAYER_LOGIN")')
res = {"hooked on Chattynator's link handler": E("HANDLER.scripts.OnHyperlinkClick ~= nil")}
L(r'''
  OLD = "|cffffff00|Hquestie:123:0|h[[29] Old Title]|h|r"
  BOX.text = "need help with " .. OLD .. " anyone?"
  HANDLER.scripts.OnHyperlinkClick(HANDLER, "questie:123:0", OLD, "LeftButton")
''')
res["shift-click: the link replaced by Questie's fresh one, the typed text kept"] = (
    E("BOX.text") == "need help with |cffffff00|Hquestie:123:0|h[[30] The Fresh Title]|h|r anyone?")
L('SHIFT = false; BOX.text = "x"; HANDLER.scripts.OnHyperlinkClick(HANDLER, "questie:123:0", "", "LeftButton"); SHIFT = true')
res["a plain click (no Shift): the chat box left alone"] = E("BOX.text") == "x"
L('BOX.text = "hi"; HANDLER.scripts.OnHyperlinkClick(HANDLER, "item:6948", "", "LeftButton")')
res["another kind of link: left alone"] = E("BOX.text") == "hi"
res["no errors"] = E("ERRS") == 0
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
