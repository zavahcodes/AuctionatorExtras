-------------------------------------------------------------------------------
--  Options: a page in Blizzard's Settings panel (Esc > Options > AddOns >
--  Auctionator Extras), built from the registered modules. One section per
--  module, in .toc order. Settings write straight into AuctionatorExtrasDB.
-------------------------------------------------------------------------------
local _, ns = ...

local CATEGORY_NAME = "Auctionator Extras"

function ns.InitOptions()
    if ns.settingsCategory or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    local category, layout = Settings.RegisterVerticalLayoutCategory(CATEGORY_NAME)
    ns.settingsCategory = category

    local function Register(key, varType, label)
        return Settings.RegisterAddOnSetting(category, "AUCX_" .. key, key, ns.db,
            varType, label, ns.DEFAULTS[key])
    end

    local builders = {
        checkbox = function(opt)
            local setting = Register(opt.key, Settings.VarType.Boolean, opt.label)
            Settings.CreateCheckbox(category, setting, opt.tooltip)
            return setting
        end,
        slider = function(opt)
            local setting = Register(opt.key, Settings.VarType.Number, opt.label)
            local options = Settings.CreateSliderOptions(opt.min, opt.max, opt.step)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(category, setting, options, opt.tooltip)
            return setting
        end,
        button = function(opt)
            if layout and CreateSettingsButtonInitializer then
                layout:AddInitializer(CreateSettingsButtonInitializer(opt.label, opt.buttonText, opt.onClick, opt.tooltip, true))
            end
        end,
        dropdown = function(opt)
            local setting = Register(opt.key, Settings.VarType.String, opt.label)
            local function GetOptions()
                local container = Settings.CreateControlTextContainer()
                for _, choice in ipairs(opt.choices) do container:Add(choice[1], choice[2]) end
                return container:GetData()
            end
            Settings.CreateDropdown(category, setting, GetOptions, opt.tooltip)
            return setting
        end,
    }

    for _, module in ipairs(ns.modules) do
        if module.options and #module.options > 0 then
            if module.name and layout and CreateSettingsListSectionHeaderInitializer then
                layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(module.name))
            end
            for _, opt in ipairs(module.options) do
                local build = builders[opt.type]
                assert(build, "AuctionatorExtras: unknown option type " .. tostring(opt.type))
                local setting = build(opt)
                if setting and module.Refresh then
                    setting:SetValueChangedCallback(function() module.Refresh(ns.db) end)
                end
            end
        end
    end

    Settings.RegisterAddOnCategory(category)
end

SLASH_AUCTIONATOREXTRAS1 = "/aucx"
SLASH_AUCTIONATOREXTRAS2 = "/auctionatorextras"
SlashCmdList.AUCTIONATOREXTRAS = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    if cmd and cmd ~= "" then
        local fn = ns.slashCommands[cmd:lower()]
        if fn then
            fn(rest)
        else
            local names = {}
            for name in pairs(ns.slashCommands) do names[#names + 1] = name end
            table.sort(names)
            ns.Print("unknown command '" .. cmd .. "'. Commands: " .. table.concat(names, ", "))
        end
        return
    end
    local category = ns.settingsCategory
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    end
end
