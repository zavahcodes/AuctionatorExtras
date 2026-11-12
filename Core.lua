-------------------------------------------------------------------------------
--  AuctionatorExtras: core. Saved settings and a tiny module registry.
--
--  Adding a feature = one file in Modules/ that calls ns.RegisterModule{...}
--  and one line in the .toc. The core merges its defaults into the saved
--  variables, builds its options section and calls its OnLoad once settings
--  are ready. Modules read ns.db at call time, so options apply live.
--
--  Module spec:
--    key      unique id (string)
--    name     section header in the options panel
--    defaults { settingKey = defaultValue, ... }
--    options  list of controls, each one of:
--               { type = "checkbox", key, label, tooltip }
--               { type = "slider",   key, label, tooltip, min, max, step }
--               { type = "dropdown", key, label, tooltip, choices = { {value, text}, ... } }
--               { type = "button",   label, buttonText, tooltip, onClick }  (no setting)
--    OnLoad   optional fn(db), called once after saved variables load
--    Refresh  optional fn(db), called whenever one of its settings changes
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.modules = {}
ns.DEFAULTS = {}

-- Live table; replaced by the saved one on ADDON_LOADED.
ns.db = {}

function ns.RegisterModule(module)
    assert(type(module) == "table" and module.key, "AuctionatorExtras: module needs a key")
    for k, v in pairs(module.defaults or {}) do
        assert(ns.DEFAULTS[k] == nil, "AuctionatorExtras: duplicate setting " .. k)
        ns.DEFAULTS[k] = v
        ns.db[k] = v
    end
    ns.modules[#ns.modules + 1] = module
    return module
end

-- Slash subcommands: "/aucx <name> ..." calls fn(rest). Plain "/aucx" prints where the options are.
ns.slashCommands = {}
function ns.RegisterSlash(name, fn)
    ns.slashCommands[name:lower()] = fn
end

function ns.Print(msg)
    print("|cff00ccffAuctionatorExtras|r: " .. msg)
end

local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    AuctionatorExtrasDB = AuctionatorExtrasDB or {}
    for k, v in pairs(ns.DEFAULTS) do
        if AuctionatorExtrasDB[k] == nil then AuctionatorExtrasDB[k] = v end
    end
    ns.db = AuctionatorExtrasDB
    for _, module in ipairs(ns.modules) do
        if module.OnLoad then SafeCall(module.OnLoad, ns.db) end
    end
    if ns.InitOptions then ns.InitOptions() end
end)
