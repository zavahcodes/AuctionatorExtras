-------------------------------------------------------------------------------
--  Tooltip spacing: a small gap above and below the price block (Auctionator's
--  lines plus this addon's own, e.g. Disenchant) so it stands apart from the
--  item text above and other addons' lines below.
--
--  A gap is an extra " " line whose font is swapped for a tiny one, so it is
--  only a few pixels tall. The original font is put back when the tooltip is
--  cleared, so reused line slots never keep the tiny font.
--
--  Top gap: added right before the first block line, either by the wrapper
--  around Auctionator.Tooltip.ShowTipWithPricingDBKey or by a module calling
--  ns.TooltipBlockStart(tooltip) before adding its own lines.
--  Bottom gap: added by this file's item post call, which is registered after
--  every other module's (it comes later in the .toc), so it closes the block.
--  Load order: after the modules that add price lines, before the rest.
-------------------------------------------------------------------------------
local _, ns = ...

if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType) then
    return
end

ns.RegisterModule({
    key = "tooltipSpacing",
    name = "Tooltip Spacing",
    defaults = {
        tooltipSpacing = true,
        tooltipSpacingSize = 6,
    },
    options = {
        { type = "checkbox", key = "tooltipSpacing", label = "Space around price lines",
          tooltip = "Adds a small gap above and below Auctionator's price lines (Vendor, Auction, ..., Disenchant)." },
        { type = "slider", key = "tooltipSpacingSize", label = "Gap size",
          tooltip = "Height of each gap, in pixels.", min = 2, max = 14, step = 1 },
    },
})

local gapFonts = {}
local function GapFont(size)
    if not gapFonts[size] then
        local font = CreateFont("AuctionatorExtrasGapFont" .. size)
        font:SetFont(STANDARD_TEXT_FONT, size, "")
        gapFonts[size] = font
    end
    return gapFonts[size]
end

-- Per tooltip: { top = lineIndex, started = bool,
--   gaps = { [fontString] = gapFont }, restore = { [fontString] = fontObject } }
local states = setmetatable({}, { __mode = "k" })

local function ApplyFont(fontString, fontObject)
    fontString:SetFontObject(fontObject)
    -- Re-set the text so the line is measured with the new font right away.
    fontString:SetText(fontString:GetText() or " ")
end

-- Skins restyle every tooltip line when the tooltip is shown (EllesmereUI's
-- Blizzard skin sets its font family on all lines, then re-Shows to resize),
-- which turned the gaps back into full lines for a moment. This OnShow hook
-- is installed later than theirs, so it runs after: put the gap fonts back
-- and resize again, all before the tooltip is drawn.
local relaying = setmetatable({}, { __mode = "k" })
local function OnShow(self)
    local s = states[self]
    if not s or not next(s.gaps) or relaying[self] then return end
    for fontString, gapFont in pairs(s.gaps) do
        ApplyFont(fontString, gapFont)
    end
    relaying[self] = true
    pcall(self.Show, self)
    relaying[self] = nil
end

local function State(tooltip)
    local state = states[tooltip]
    if not state then
        state = { restore = {}, gaps = {} }
        states[tooltip] = state
        tooltip:HookScript("OnTooltipCleared", function(self)
            local s = states[self]
            for fontString, fontObject in pairs(s.restore) do
                fontString:SetFontObject(fontObject)
            end
            wipe(s.restore)
            wipe(s.gaps)
            s.top, s.started = nil, false
        end)
        tooltip:HookScript("OnShow", OnShow)
    end
    return state
end

local function LineFontString(tooltip, index)
    local name = tooltip:GetName()
    return name and _G[name .. "TextLeft" .. index]
end

local function SetLineFont(tooltip, state, index, fontObject)
    local fontString = LineFontString(tooltip, index)
    if not fontString then return end
    if state.restore[fontString] == nil then
        state.restore[fontString] = fontString:GetFontObject() or GameTooltipText
    end
    state.gaps[fontString] = fontObject
    ApplyFont(fontString, fontObject)
end

local function AddGap(tooltip, state)
    tooltip:AddLine(" ")
    local index = tooltip:NumLines()
    SetLineFont(tooltip, state, index, GapFont(ns.db.tooltipSpacingSize))
    return index
end

local function Usable(tooltip)
    return ns.db.tooltipSpacing and tooltip and not tooltip:IsForbidden()
        and tooltip.GetName and tooltip:GetName() and tooltip.NumLines
end

-- Call before adding price-block lines; adds the top gap once per tooltip.
function ns.TooltipBlockStart(tooltip)
    if not Usable(tooltip) then return end
    local state = State(tooltip)
    if state.started then return end
    if state.top then
        -- A gap left collapsed by an empty Auctionator pass: reopen it.
        SetLineFont(tooltip, state, state.top, GapFont(ns.db.tooltipSpacingSize))
    else
        state.top = AddGap(tooltip, state)
    end
    state.started = true
end

-- Wrap Auctionator's line writer: gap first, then its lines. If it ended up
-- adding nothing, collapse the gap to 1 px (a line can't be removed).
if Auctionator and Auctionator.Tooltip and Auctionator.Tooltip.ShowTipWithPricingDBKey then
    local original = Auctionator.Tooltip.ShowTipWithPricingDBKey
    Auctionator.Tooltip.ShowTipWithPricingDBKey = function(tooltip, ...)
        if not Usable(tooltip) or State(tooltip).started then
            return original(tooltip, ...)
        end
        local state = State(tooltip)
        ns.TooltipBlockStart(tooltip)
        local before = tooltip:NumLines()
        local results = { pcall(original, tooltip, ...) }
        if tooltip:NumLines() == before then
            SetLineFont(tooltip, state, state.top, GapFont(1))
            state.started = false
        end
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2)
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
    if not Usable(tooltip) then return end
    local state = states[tooltip]
    if state and state.started then
        AddGap(tooltip, state)
        state.started = false
        state.top = nil -- block closed; a later refresh pass starts a new one
        -- Lay the tooltip out now with the gap heights, before it's drawn.
        if tooltip:IsShown() then tooltip:Show() end
    end
end)
