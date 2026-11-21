-- .luacheckrc for level M/L -- with the core/ <-> wow/ BOUNDARY ACTUALLY ENFORCED.
-- Repo-root .luacheckrc (level M/L).
-- Docs: https://luacheck.readthedocs.io/en/stable/config.html
--
-- KEY FACT (verified, 12.0.7 / luacheck 1.2.0): in luacheck the `globals` of a files{} block
-- EXTENDS the top-level one, it does NOT replace it. That is why the WoW globals are NOT
-- declared at the top (up there they would leak into core/ and the boundary would not bite):
-- they are declared PER LAYER. So core/ inherits only `LibStub` and any WoW API there is a
-- W113. (loom/weave keep theirs at the top -> their boundary is aspirational today, the
-- linter does not enforce it; this template fixes that.)

std             = "lua51"      -- WoW runs Lua 5.1
max_line_length = 120
color           = true

-- CONVENTION for the `globals` lists below (Coffer pattern): group by area and comment every
-- block with WHICH feature/milestone introduced it -- the file ends up documenting the addon's
-- WoW API surface. And NEVER add a variable here to silence an `accessing undefined variable
-- 'X'`: that is a forward-declare bug, not a game global (doc 03 section 2).
--
-- DO NOT declare a global that a patch REMOVED, and do not stub it in the test mock. FrameXML
-- globals have no contract (widget methods and C_* do): 12.1.5 deleted `GetItemInfo`,
-- `GetDetailedItemLevelInfo` and `MouseIsOver()`, and Craft needed a hotfix release (v0.90).
-- With the name absent from this list, luacheck flags every reintroduction (W113) the day you
-- bump `## Interface:` -- the guardrail is the ABSENCE. Procedure: doc 03 section 3 (patch cycle).
--
-- Top level: ONLY what may appear in any layer (core/ included).
globals = {
    "LibStub",
}

ignore = {
    "212",   -- unused argument (OnEvent callbacks)
    "213",   -- unused loop variable
}

files = {
    -- core/ = pure Lua. Inherits `LibStub` only. Any WoW API here => W113 (fails).
    -- The scheduler and the secret detector are INJECTED from wow/, never called directly.
    ["QuantumDungeonTools/core/"] = {
        globals = {},
    },

    -- wow/ = the integration layer: this is where the game globals live. EXTEND as needed.
    ["QuantumDungeonTools/wow/"] = {
        globals = {
            "CreateFrame", "UIParent", "UISpecialFrames",
            "GetTime", "GetLocale", "InCombatLockdown",
            "C_Timer", "C_AddOns",
            "issecretvalue", "issecrettable",
            "print",
            "QuantumDungeonToolsDB",
            -- Main window (MainWindow.lua, plan M1 F6b)
            "time", "ReloadUI",
            -- Minimap icon (Minimap.lua, plan M1 F6e): LibDBIcon button, own tooltip
            "LibStub", "IsShiftKeyDown", "_G",
        },
    },
    -- Research probe for own dungeon coordinates (CheckPos.lua, docs/27): position, range, ping.
    ["QuantumDungeonTools/wow/CheckPos.lua"] = {
        globals = {
            "GetInstanceInfo", "IsInInstance", "IsIndoors", "GetMinimapZoneText", "UnitPosition",
            "GetPlayerFacing", "C_Map", "GetUnitSpeed", "C_Minimap", "GetCVar", "Minimap", "date",
            "UnitExists", "UnitIsConnected", "UnitIsVisible", "UnitDistanceSquared", "UnitInRange",
            "CheckInteractDistance", "C_Item", "IsItemInRange", "UnitIsUnit",
            "EnumerateFrames", "C_Ping", "Enum",
        },
    },

    -- Research probe for the minimap map switch at the Undercity gate (CheckDoor.lua, LECCIONES).
    ["QuantumDungeonTools/wow/CheckDoor.lua"] = {
        globals = {
            "Minimap", "C_Minimap", "C_CVar", "GetCVar", "IsIndoors", "IsOutdoors",
            "GetMinimapZoneText", "GetRealZoneText", "GetSubZoneText", "date",
        },
    },

    -- Modules: same split. modules/<Name>/core/ is pure (inherits nothing); modules/<Name>/wow/
    -- gets the game globals that module uses (added by: Instance Tracker, v0.1).
    ["QuantumDungeonTools/modules/InstanceTracker/core/"] = {
        globals = {},
    },
    ["QuantumDungeonTools/modules/InstanceTracker/wow/"] = {
        globals = {
            "CreateFrame", "UIParent", "C_Timer", "time", "geterrorhandler",
            "GetMoneyString", "GetCoinTextureString",
            "GetInstanceInfo", "INSTANCE_RESET_SUCCESS", "GetInstanceLockTimeRemaining", "GetInstanceLockTimeRemainingEncounter",
            "RequestRaidInfo", "UnitXP", "UnitXPMax", "UnitLevel",
            -- F1 probes (CheckF1.lua, v0.1.1)
            "UnitGUID", "UnitExists", "UnitName", "UnitFullName", "UnitAffectingCombat", "GetBuildInfo",
            "GetNumSavedInstances", "GetSavedInstanceInfo", "print", "QuantumDungeonToolsDB",
            -- F2 widget on Craft (UI.lua, Tracker:XPSnapshot, CheckF2.lua, v0.2)
            "LibStub", "GetXPExhaustion", "GetMaxLevelForPlayerExpansion", "GetMaxPlayerLevel",
            "IsXPUserDisabled", "GetLocale",
            -- Boss ping (UI.lua, plan M1 point 7): secure buttons + attack cursor
            "InCombatLockdown", "SetCursor", "ResetCursor", "wipe",
            -- Alerts (Alerts.lua, plan M1 F5): share line + the game's "too many instances"
            "IsInGroup", "IsInRaid", "LE_PARTY_CATEGORY_INSTANCE", "SendChatMessage", "C_ChatInfo",
            "TRANSFER_ABORT_TOO_MANY_INSTANCES", "ERR_TOO_MANY_INSTANCES",
            -- History tab (HistoryTab.lua, plan M1 F6d): run dates
            "date",
        },
    },

    -- Minimap Lens (plan M2). core/ is pure (F2: lens state, limits, snapshot checks).
    ["QuantumDungeonTools/modules/MinimapLens/core/"] = {
        globals = {},
    },
    -- F1 probes (CheckM2.lua): Minimap setters, LibDBIcon, tracking,
    -- edit mode; GetMinimapShape is WRITTEN (square lens) and BINDING_* name the lens binding (F4).
    ["QuantumDungeonTools/modules/MinimapLens/wow/"] = {
        globals = {
            "CreateFrame", "UIParent", "C_Timer", "C_AddOns", "C_Minimap", "GetTime", "InCombatLockdown",
            "Minimap", "MinimapCluster", "GetMinimapShape", "hooksecurefunc", "debugstack",
            "GetBuildInfo", "GetCVar", "SetCVar", "GetBindingKey", "EventRegistry",
            "issecrettable", "LibStub", "_G", "QuantumDungeonToolsDB",
            "GetBindingText", "IsInInstance", "UISpecialFrames", "tinsert", "Settings",
            "BINDING_HEADER_QDT", "BINDING_NAME_QDT_LENS",
        },
    },

    -- Locale.lua and Config.lua touch little of the game; each gets its own narrow scope.
    ["QuantumDungeonTools/Locale.lua"] = {
        globals = { "GetLocale" },
    },
    ["QuantumDungeonTools/Config.lua"] = {
        globals = { "print", "SlashCmdList", "SLASH_QDT1", "LibStub" },
    },

    -- tests/: the mini-runner DSL (run.lua defines it) plus the mocks the specs put in _G.
    ["tests/"] = {
        globals = {
            "describe", "it",
            "assert_eq", "assert_true", "assert_false", "assert_error",
            "CreateFrame", "C_Timer", "C_AddOns", "GetLocale", "print", "QuantumDungeonToolsDB",
        },
    },
}

exclude_files = {
    "**/libs/",          -- vendored: not linted (libs/ lowercase, standard doc 01)
    "related-addons/",
    "docs/", "scripts/", "templates/",
}
