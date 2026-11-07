-------------------------------------------------------------------------------
--  Disenchant value: a "Disenchant" line on weapon/armor tooltips with the
--  expected auction value of the materials the item disenchants into, so you
--  can compare it with the item's own auction and vendor price. Hold Shift to
--  list the possible materials. Only shown on characters that know Disenchant.
--
--  Auctionator has its own disenchant line, but on Forever it runs the retail
--  code path, which only knows WoD+ materials; this module uses the vanilla
--  table in Data/DisenchantTable.lua and Auctionator's scanned prices.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType) then
    return
end

local DISENCHANT_SPELL = 13262
local LABEL = "Disenchant"

local TABLE = ns.DisenchantTable
local ESSENCE_PAIRS = ns.DisenchantEssencePairs
local GREATER_TO_LESSER = {}
for lesser, greater in pairs(ESSENCE_PAIRS) do GREATER_TO_LESSER[greater] = lesser end

ns.RegisterModule({
    key = "disenchantValue",
    name = "Disenchant",
    defaults = {
        disenchantValue = true,
    },
    options = {
        { type = "checkbox", key = "disenchantValue", label = "Show disenchant value",
          tooltip = "Adds a Disenchant line to weapon and armor tooltips with the expected auction value "
              .. "of the materials it disenchants into (hold Shift for the list of materials). "
              .. "Only on characters that know Disenchant." },
    },
})

local function KnowsDisenchant()
    if IsPlayerSpell then return IsPlayerSpell(DISENCHANT_SPELL) end
    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(DISENCHANT_SPELL) end
    return false
end

local function AuctionPrice(itemID)
    return Auctionator.API.v1.GetAuctionPriceByItemID(ADDON_NAME, itemID)
end

-- Essences convert 3 lesser <-> 1 greater, so each is worth at most the
-- other one's price scaled by 3.
local function MaterialPrice(itemID)
    local price = AuctionPrice(itemID)
    local greater = ESSENCE_PAIRS[itemID]
    local lesser = GREATER_TO_LESSER[itemID]
    if greater then
        local gp = AuctionPrice(greater)
        if gp and (not price or gp / 3 < price) then price = gp / 3 end
    elseif lesser then
        local lp = AuctionPrice(lesser)
        if lp and (not price or lp * 3 < price) then price = lp * 3 end
    end
    return price
end

local function FindRow(classID, quality, itemLevel)
    local rows = TABLE[classID] and TABLE[classID][quality]
    if not rows or not itemLevel then return nil end
    for _, row in ipairs(rows) do
        if itemLevel >= row[1] and itemLevel <= row[2] then return row end
    end
end

-- Expected copper value of the row, or nil when any material has no price.
local function RowValue(row)
    local total = 0
    for i = 3, #row, 3 do
        local price = MaterialPrice(row[i + 2])
        if not price then return nil end
        total = total + row[i] / 100 * row[i + 1] * price
    end
    return math.floor(total)
end

local function MaterialName(itemID)
    return (C_Item.GetItemInfo(itemID)) or ns.DisenchantMatNames[itemID] or ("item:" .. itemID)
end

local function Round1(n)
    return math.floor(n * 10 + 0.5) / 10
end

-- One entry per material, in table order: total chance of getting it and the
-- chance-weighted quantity (weightedQty / pct = average stack when it drops).
local function GroupMaterials(row)
    local list, byID = {}, {}
    for i = 3, #row, 3 do
        local pct, qty, itemID = row[i], row[i + 1], row[i + 2]
        local mat = byID[itemID]
        if not mat then
            mat = { itemID = itemID, pct = 0, weightedQty = 0 }
            byID[itemID] = mat
            list[#list + 1] = mat
        end
        mat.pct = mat.pct + pct
        mat.weightedQty = mat.weightedQty + pct * qty
    end
    return list
end

local function FormatMoney(value)
    local text
    if Auctionator.Utilities and Auctionator.Utilities.CreatePaddedMoneyString then
        text = Auctionator.Utilities.CreatePaddedMoneyString(value)
    else
        text = GetMoneyString(value, true)
    end
    return WHITE_FONT_COLOR:WrapTextInColorCode(text)
end

local function OnItemTooltip(tooltip)
    if not ns.db.disenchantValue or tooltip:IsForbidden() or not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    if not link or not KnowsDisenchant() then return end

    local _, _, quality, _, _, _, _, _, _, _, _, classID = C_Item.GetItemInfo(link)
    if not quality then return end
    local itemLevel = C_Item.GetDetailedItemLevelInfo(link)
    local row = FindRow(classID, quality, itemLevel)
    if not row then return end

    local value = RowValue(row)
    tooltip:AddDoubleLine(LABEL, value and FormatMoney(value) or WHITE_FONT_COLOR:WrapTextInColorCode("?  "))

    if IsShiftKeyDown() then
        for _, mat in ipairs(GroupMaterials(row)) do
            local avgQty = mat.weightedQty / mat.pct
            local price = MaterialPrice(mat.itemID)
            tooltip:AddDoubleLine(
                string.format("  %s %sx %s",
                    WHITE_FONT_COLOR:WrapTextInColorCode(string.format("%g%%", Round1(mat.pct))),
                    string.format("%g", Round1(avgQty)), MaterialName(mat.itemID)),
                price and FormatMoney(math.floor(avgQty * price)) or WHITE_FONT_COLOR:WrapTextInColorCode("?  "))
        end
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
    local ok, err = pcall(OnItemTooltip, tooltip)
    if not ok then geterrorhandler()(err) end
end)
