# Chat_AddonWhispers: "No player named 'X' is currently playing." hidden when an addon's hidden whisper went to X
# in the last 10 s - never when you typed a whisper to X yourself; the sending addon recorded for /mo whispers.
import sys
from lupa import LuaRuntime
src = open(sys.argv[1], encoding="utf-8").read()
lua = LuaRuntime()
import os as _os; sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))  # (run with -I)
from shared_lua import load_shared; load_shared(lua, sys.argv[1])
lua.execute("function MasterOptions_Module(name, needs, body) body('MasterOptions_' .. name) end")
lua.execute(r'''
  NOW = 100
  function GetTime() return NOW end
  function hooksecurefunc(t, k, fn)
    if type(t) == "string" then local o = _G[t]; _G[t] = function(...) local r = o(...); k(...); return r end; return end
    local o = t[k]; t[k] = function(...) local r = o(...); fn(...); return r end
  end
  STACK = "Interface/AddOns/OpenMap/Map/Friends.lua:268: in function <...>"
  function debugstack() return "Interface/AddOns/MasterOptions/Modules/Chat_AddonWhispers.lua:1: in hook\n" .. STACK end
  C_ChatInfo = { SendAddonMessage = function() return true end, SendChatMessage = function() end }
  function SendChatMessage() end
  ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
  FILTERS = {}
  function ChatFrame_AddMessageEventFilter(ev, fn) FILTERS[ev] = fn end
  PRINTS = {}
  function print(s) PRINTS[#PRINTS + 1] = s end
  function Hidden(name) return FILTERS.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", ("No player named '%s' is currently playing."):format(name)) == true end
''')
lua.eval("function(s) return load(s, '=p') end")(src)("MasterOptions_Chat_AddonWhispers")
L, E = lua.execute, lua.eval
res = {}
L('C_ChatInfo.SendAddonMessage("OMF", "hello", "WHISPER", "Kronoz Dobryak")')
res["an addon's hidden whisper to Kronoz Dobryak: his 'No player named' line hidden"] = E('Hidden("Kronoz Dobryak")')
res["someone no addon whispered: the line shows"] = E('Hidden("Someone Else")') is False
L('NOW = NOW + 11')
res["more than 10 s later: shows again"] = E('Hidden("Kronoz Dobryak")') is False
L('C_ChatInfo.SendAddonMessage("MC", "q", "WHISPER", "Skeb Oomnomnom-Realm"); SendChatMessage("hi", "WHISPER", nil, "Skeb Oomnomnom")')
res["you typed a whisper to them too: your answer shows"] = E('Hidden("Skeb Oomnomnom")') is False
L('NOW = NOW + 11; C_ChatInfo.SendAddonMessage("Q", "x", "WHISPER", "Third Person-Some Realm")')
res["a realm on the target: matched by name"] = E('Hidden("Third Person")')
L('C_ChatInfo.SendAddonMessage("P", "x", "PARTY")')
res["party / guild addon messages aren't whispers: nothing recorded"] = E('#MasterOptions_AddonWhispers.Recent()') == 3
L('MasterOptions_AddonWhispers.List()')
lines = "\n".join(lua.eval("table.concat(PRINTS, '\\n')").split("\n"))
res["/mo whispers names the addon (not Master Options, not a library) and marks the hidden ones"] = (
    "OpenMap" in lines and "Kronoz Dobryak" in lines and "not online" in lines)
for k, v in res.items():
    print(("ok   " if v else "FAIL ") + k)
print("ERRORS:", sum(1 for v in res.values() if not v))
