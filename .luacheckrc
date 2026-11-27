-- luacheck config for Master Options (WoW Forever client, Lua 5.1). Run: .\scripts\lint.ps1 (CI runs it too).
std = "lua51"
max_line_length = false       -- long tooltip strings and comments are the house style
exclude_files = { "addons/MasterOptions/Libs/**", ".venv/**", ".tools/**", "dist/**", "tests/**" }

-- WoW callbacks get arguments they don't use (self, event, ...); not worth a warning each
unused_args = false

-- Deliberate, one name in one file each:
-- WoW's Lua 5.1 has unpack; the sandbox tests' newer Lua only table.unpack (`unpack or table.unpack`)
files["addons/MasterOptions/Modules/OpenMapMiniMap_Border.lua"] = { ignore = { "143/table" } }
-- the reward pre-select writes the game's own choice field, QuestInfoFrame.itemChoice
files["addons/MasterOptions/Modules/DialogKey_Pawn.lua"] = { ignore = { "122/QuestInfoFrame" } }

-- Globals Master Options defines (saved variables, its slash command, what modules share)
globals = {
    "MasterOptionsDB", "MasterOptions_DialogKeyPawnDB", "MasterOptions_DJOpenMapDB", "MasterOptions_GearMaticForeverDB",
    "MasterOptions_MastercraftBankDB", "MasterOptions_MastercraftKeepDB", "MasterOptions_MastercraftVendorDB",
    "MasterOptions_MinimapBorderDB",
    "MasterOptions_Module", "MasterOptions_Modules", "MasterOptions_ErrorLog", "MasterOptions_ReportError",
    "MasterOptions_MastercraftKeep", "MasterOptions_MastercraftVendorSell", "MasterOptions_MinimapBorder",
    "MasterOptions_NeverSell", "MasterOptions_PawnKeeps", "MasterOptions_PawnKeepsMany",
    "MasterOptions_GearKeeps", "MasterOptions_GearKeepsMany", "MasterOptions_GearMaticSpecKeeps", "MasterOptions_CheapUpgradesGearMatic", "MasterOptions_Shared", "MasterOptions_FarmTour",
    "SLASH_MASTEROPTIONS1", "SLASH_MASTEROPTIONS2",
    -- Blizzard tables we add entries to
    "SlashCmdList", "UISpecialFrames",
}

-- The game's API and frames, and other addons' globals we read (their saved variables are read through _G.X)
read_globals = {
    -- Lua extras in WoW
    "date", "time", "debugstack", "geterrorhandler", "seterrorhandler", "tinsert", "wipe", "hooksecurefunc",
    -- C_ namespaces and Enum
    "C_AddOns", "C_Bank", "C_Container", "C_Item", "C_Map", "C_Minimap", "C_Spell", "C_Texture", "C_Timer", "Enum",
    -- API functions
    "CreateFrame", "DisableAddOn", "EnableAddOn", "GetAddOnDependencies", "GetAddOnEnableState", "GetAddOnInfo",
    "GetAddOnMetadata", "GetBuildInfo", "GetCVar", "GetCoinTextureString", "GetItemInfo", "GetNumAddOns",
    "GetNumQuestChoices", "GetNumSkillLines", "GetProfessionInfo", "GetProfessions", "GetQuestItemInfo",
    "GetQuestItemLink", "GetRealmName", "GetSkillLineInfo", "GetSpellInfo", "GetTime", "GetTrackingTexture",
    "HideUIPanel", "InCombatLockdown", "IsAddOnLoadOnDemand", "IsAddOnLoaded", "IsEquippableItem", "IsInInstance",
    "IsModifierKeyDown", "IsResting", "ReloadUI", "UnitClass", "UnitGUID", "UnitName", "UseContainerItem",
    "GameTooltip_Hide", "QuestInfoItem_OnClick", "QuestInfo_GetRewardButton",
    "GetCursorInfo", "ClearCursor", "GetItemIcon", "ChatEdit_InsertLink", "ChatFrameUtil",
    "CreateSettingsButtonInitializer", "CreateSettingsListSectionHeaderInitializer",
    -- frames and other game objects
    "AuctionFrame", "AuctionHouseFrame", "BankFrame", "ChatFontNormal", "ChatFrame1", "GameTooltip", "ItemLocation",
    "Minimap", "MinimapCluster", "QuestFrameRewardPanel", "QuestInfoFrame", "Settings", "SettingsPanel",
    "TooltipDataProcessor", "UIParent", "WorldFrame", "WorldMapFrame",
    -- constants
    "BANK_CONTAINER", "NUM_BAG_SLOTS", "NUM_BANKBAGSLOTS", "NUM_TOTAL_EQUIPPED_BAG_SLOTS",
    -- libraries and other addons
    "LibStub", "Baganator", "Chattynator",
}
