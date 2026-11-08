-------------------------------------------------------------------------------
--  TSM prices: feeds TSM Desktop's AuctionDB prices into Auctionator's price
--  database and turns off Auctionator's own AH scanning. TSM itself does NOT
--  need to be enabled.
--
--  Data: TSM Desktop writes TradeSkillMaster_AppHelper/AppData.lua, which is
--  only loaded by WoW when TSM is enabled. Our .toc lists that file directly
--  (by relative path), right after this module, so no copy or link is needed.
--  Each of its lines calls select(2, ...).LoadData(tag, realmOrRegion, data),
--  and select(2, ...) is our namespace, so ns.LoadData below receives it. The
--  data strings are decoded the same way TSM does (LibTSMService AuctionDB:
--  "{itemID,v1,v2,...}" rows, values in base 32 copper).
--
--  Import: prices are written with Auctionator.Database:ProcessScan, the same
--  path a full scan uses (current price + daily history), then PricesProcessed
--  is fired so Auctionator refreshes. The AppData file is only read at UI load,
--  so imports run on login/reload when the data is newer than the last import,
--  or on demand (/aucx import, options button, or Auctionator's scan button,
--  which becomes "Import TSM").
-------------------------------------------------------------------------------
local _, ns = ...

local LOGIN_DELAY = 2
local BUTTON_TEXT = "Import TSM"

local SOURCES = {
    { "DBMarket",          "Market Value (DBMarket)" },
    { "DBMinBuyout",       "Minimum Buyout (DBMinBuyout)" },
    { "DBRecent",          "Recent Value (DBRecent)" },
    { "DBHistorical",      "Historical Price (DBHistorical)" },
    { "DBRegionMarketAvg", "Region Market Value (DBRegionMarketAvg)" },
}

-- TSM price source -> field name in the AppData tables, and whether it's
-- realm data (realm + commodity tags) or region data.
local SOURCE_FIELDS = {
    DBMarket          = { field = "marketValue",       region = false },
    DBMinBuyout       = { field = "minBuyout",         region = false },
    DBRecent          = { field = "marketValueRecent", region = false },
    DBHistorical      = { field = "historical",        region = false },
    DBRegionMarketAvg = { field = "regionMarketValue", region = true },
    DBNumAuctions     = { field = "numAuctions",       region = false },
}

local Import -- forward declaration

-------------------------------------------------------------------------------
--  Receive and decode TSM Desktop's AppData
-------------------------------------------------------------------------------
-- Raw blocks as loaded; decoded on import, once the player's realm/faction is known.
local rawBlocks = {} -- { {tag, realmOrRegion, data}, ... }

function ns.LoadData(tag, realmOrRegion, data)
    if type(tag) == "string" and tag:find("^AUCTIONDB_")
        and type(realmOrRegion) == "string" and type(data) == "string" then
        rawBlocks[#rawBlocks + 1] = { tag = tag, where = realmOrRegion, data = data }
    end
end

local function Base32Copper(val)
    if #val > 6 then
        -- tonumber only handles 32-bit values, so split it like TSM does
        local lower = tonumber(val:sub(-6), 32)
        local upper = tonumber(val:sub(1, -7), 32)
        if not (lower and upper) then return nil end
        return lower + upper * 2 ^ 30
    end
    return tonumber(val, 32)
end

-- Decodes one block into fields[fieldName][itemID] = value. Only plain item
-- IDs are kept (Auctionator's basic keys); level variants are skipped.
local function DecodeBlock(block, fields)
    local fieldList = {}
    local fieldsText = block.data:match("fields={(.-)}")
    if not fieldsText then return 0 end
    for name in fieldsText:gmatch('"([^"]+)"') do fieldList[#fieldList + 1] = name end
    local downloadTime = tonumber(block.data:match("downloadTime=(%d+)")) or 0
    for itemString, rest in block.data:gmatch('{"?([^,"{}]+)"?,([^{}]+)}') do
        local id = tonumber(itemString) or tonumber(itemString:match("^i:(%d+)$"))
        if id then
            local i = 2 -- fieldList[1] is "itemString"
            for val in (rest .. ","):gmatch("([^,]*),") do
                local name = fieldList[i]
                if name and val ~= "" then
                    fields[name] = fields[name] or {}
                    fields[name][id] = Base32Copper(val)
                end
                i = i + 1
            end
        end
    end
    return downloadTime
end

local function IsGameRuleActive(ruleName)
    local rule = Enum and Enum.GameRule and Enum.GameRule[ruleName]
    return rule ~= nil and C_GameRules and C_GameRules.IsGameRuleActive
        and C_GameRules.IsGameRuleActive(rule) == true
end

local function IsHardcore()
    return IsGameRuleActive("HardcoreRuleset")
end

-- Realm name as TSM keys its data. On Forever, TSM names realms after their
-- ruleset, not the real realm (LibTSMWoW/Source/Util/SessionInfo.lua).
local function TSMRealmName()
    if not (C_GameRules and Enum and Enum.GameRule) then return GetRealmName() or "" end
    local isRP, isPvP = IsGameRuleActive("RPRuleset"), IsGameRuleActive("PvPRuleset")
    if IsHardcore() then return "Hardcore"
    elseif isRP and isPvP then return "Roleplay PvP"
    elseif isRP then return "Roleplay"
    elseif isPvP then return "PvP"
    end
    return "Normal"
end

local function Normalize(s)
    return (s:lower():gsub("\226", "'"))
end

local function IsCurrentRealm(where)
    local realm = TSMRealmName()
    local faction = UnitFactionGroup("player") or ""
    where = Normalize(where)
    return where == Normalize(realm .. "-" .. faction) or where == Normalize(realm)
end

local function IsRegionTag(tag)
    return tag:find("^AUCTIONDB_REGION_") or tag:find("^AUCTIONDB_COMMODITY_")
end

-- Region data is keyed "Forever-EU" or "Forever-HC-EU": keep the one that
-- matches the character's ruleset.
local function IsCurrentRegion(where)
    return (where:find("%-HC%-") ~= nil) == IsHardcore()
end

-- For the "no data" message: which realms the file has vs. what we look for.
local seenRealms = {}
function ns.TSMRealmDebug()
    local names = {}
    for name in pairs(seenRealms) do names[#names + 1] = name end
    table.sort(names)
    return TSMRealmName() .. "-" .. (UnitFactionGroup("player") or "?"),
        #names > 0 and table.concat(names, ", ") or "none"
end

-- Returns realmFields, regionFields, realmTime, regionTime.
local decoded
local function Decoded()
    if decoded then return unpack(decoded) end
    local realmFields, regionFields, realmTime, regionTime = {}, {}, 0, 0
    for _, block in ipairs(rawBlocks) do
        if IsRegionTag(block.tag) then
            if IsCurrentRegion(block.where) then
                if block.tag:find("^AUCTIONDB_COMMODITY_") then
                    -- Commodities are region-wide but priced like realm data in TSM.
                    realmTime = math.max(realmTime, DecodeBlock(block, realmFields))
                else
                    regionTime = math.max(regionTime, DecodeBlock(block, regionFields))
                end
            end
        else
            seenRealms[block.where] = true
            if IsCurrentRealm(block.where) then
                realmTime = math.max(realmTime, DecodeBlock(block, realmFields))
            end
        end
    end
    rawBlocks = {} -- free the raw strings
    decoded = { realmFields, regionFields, realmTime, regionTime }
    return unpack(decoded)
end

-------------------------------------------------------------------------------
--  Import
-------------------------------------------------------------------------------
local eventSource = {}
local sourceRegistered = false
local importing = false

local function NotifyPricesUpdated()
    local bus = Auctionator.EventBus
    local events = Auctionator.IncrementalScan and Auctionator.IncrementalScan.Events
    if not (bus and events and events.PricesProcessed) then return end
    if not sourceRegistered then
        bus:RegisterSource(eventSource, "AuctionatorExtras TSM import")
        sourceRegistered = true
    end
    bus:Fire(eventSource, events.PricesProcessed)
end

-- force: import even if the data and source match the last import.
Import = function(force)
    if not ns.db.tsmPricesEnabled or importing then return end
    if not (Auctionator.Database and Auctionator.Database.ProcessScan) then return end

    local source = ns.db.tsmPriceSource
    local info = SOURCE_FIELDS[source] or SOURCE_FIELDS.DBMarket
    local realmFields, regionFields, realmTime, regionTime = Decoded()
    local prices = (info.region and regionFields or realmFields)[info.field]
    local downloadTime = info.region and regionTime or realmTime

    if not prices or next(prices) == nil then
        if force then
            local wanted, seen = ns.TSMRealmDebug()
            ns.Print(string.format("no TSM Desktop data for %s. Looking for realm '%s'; the TSM file has: %s. "
                .. "(Is the TSM Desktop app running and synced, and the "
                .. "TradeSkillMaster_AppHelper addon folder installed?)", source, wanted, seen))
        end
        return
    end
    if not force and ns.db.tsmLastImportDownloadTime == downloadTime
        and ns.db.tsmLastImportSource == source then
        return
    end

    local numAuctions = realmFields.numAuctions or {}
    local itemIndexes, count = {}, 0
    for id, price in pairs(prices) do
        if price and price > 0 then
            itemIndexes[tostring(id)] = { { price = math.floor(price), available = numAuctions[id] or 0 } }
            count = count + 1
        end
    end

    importing = true
    Auctionator.Database:ProcessScan(itemIndexes, function()
        importing = false
        ns.db.tsmLastImportDownloadTime = downloadTime
        ns.db.tsmLastImportSource = source
        NotifyPricesUpdated()
        ns.Print(string.format("imported %d TSM prices (%s, %s).", count, source,
            date("%Y-%m-%d %H:%M", downloadTime)))
    end)
end

-------------------------------------------------------------------------------
--  Turn off Auctionator's own scanning while the module is enabled
-------------------------------------------------------------------------------
local function Active()
    return ns.db.tsmPricesEnabled == true
end

local function WrapMethod(mixin, name, wrapper)
    if type(mixin) == "table" and type(mixin[name]) == "function" then
        local original = mixin[name]
        mixin[name] = function(...) return wrapper(original, ...) end
    end
end

-- Mixins are copied into frames when Auctionator creates them (on first AH
-- open, after this file loads), so patching the mixin tables is enough.
WrapMethod(AuctionatorScanButtonMixin, "OnClick", function(original, ...)
    if Active() then return Import(true) end
    return original(...)
end)
WrapMethod(AuctionatorIncrementalScanFrameMixin, "IsAutoscanReady", function(original, ...)
    if Active() then return false end
    return original(...)
end)
WrapMethod(AuctionatorFullScanFrameMixin, "IsAutoscanReady", function(original, ...)
    if Active() then return false end
    return original(...)
end)
-- Browsing the AH would otherwise overwrite imported prices with partial data.
WrapMethod(AuctionatorIncrementalScanFrameMixin, "OnEvent", function(original, self, event, ...)
    if Active() and (event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED"
        or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED") then
        return
    end
    return original(self, event, ...)
end)

local originalButtonText, originalButtonTooltip
local function UpdateScanButton()
    local configFrame = AuctionHouseFrame and AuctionHouseFrame.AuctionatorConfigFrame
    local button = configFrame and configFrame.ScanButton
    if not button then return end
    if originalButtonText == nil then
        originalButtonText = button:GetText()
        originalButtonTooltip = button.tooltipText
    end
    if Active() then
        button:SetText(BUTTON_TEXT)
        button.tooltipText = "Import prices from TSM Desktop's AuctionDB data (AuctionatorExtras). "
            .. "Auctionator's own scan is disabled while this is on."
    else
        button:SetText(originalButtonText)
        button.tooltipText = originalButtonTooltip
    end
    if DynamicResizeButton_Resize then DynamicResizeButton_Resize(button) end
end

-------------------------------------------------------------------------------
--  Module registration, events and slash command
-------------------------------------------------------------------------------
ns.RegisterModule({
    key = "tsmPrices",
    name = "TSM Prices",
    defaults = {
        tsmPricesEnabled = true,
        tsmPriceSource = "DBMarket",
        tsmLastImportDownloadTime = 0,
        tsmLastImportSource = "",
    },
    options = {
        { type = "checkbox", key = "tsmPricesEnabled", label = "Use TSM prices",
          tooltip = "Imports TSM Desktop's AuctionDB prices into Auctionator's price database on login "
              .. "(when TSM has newer data) and turns off Auctionator's own AH scanning. "
              .. "Auctionator's scan button becomes \"" .. BUTTON_TEXT .. "\"." },
        { type = "dropdown", key = "tsmPriceSource", label = "TSM price source",
          tooltip = "TSM price saved as Auctionator's auction price.",
          choices = SOURCES },
        { type = "button", label = "Import TSM prices", buttonText = "Import now",
          tooltip = "Imports the TSM prices right away, even if nothing changed since the last import.",
          onClick = function() Import(true) end },
    },
    Refresh = function()
        UpdateScanButton()
        Import(false) -- picks up a source change or the module being re-enabled
    end,
})

ns.RegisterSlash("import", function() Import(true) end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(LOGIN_DELAY, function() Import(false) end)
    elseif event == "AUCTION_HOUSE_SHOW" then
        -- Auctionator builds its tabs on AUCTION_HOUSE_SHOW; update after it.
        C_Timer.After(0.5, UpdateScanButton)
    end
end)
