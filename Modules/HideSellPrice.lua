-------------------------------------------------------------------------------
--  Hide sell price: drops Blizzard's native "Sell Price:" line from item
--  tooltips, since Auctionator already shows the vendor price. The SellPrice
--  line pre call consumes the line (returning true skips Blizzard's handler),
--  so nothing is added and nothing has to be hidden afterwards. Blizzard
--  exposes no removal API, so the hook stays installed and the setting is
--  checked on every line.
-------------------------------------------------------------------------------
local _, ns = ...

if not (TooltipDataProcessor and TooltipDataProcessor.AddLinePreCall
    and Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.SellPrice) then
    return
end

ns.RegisterModule({
    key = "hideSellPrice",
    name = "Tooltip",
    defaults = {
        hideSellPrice = true,
    },
    options = {
        { type = "checkbox", key = "hideSellPrice", label = "Hide Blizzard sell price",
          tooltip = "Removes Blizzard's own \"Sell Price:\" line from item tooltips, "
              .. "since Auctionator already shows the vendor price." },
    },
})

TooltipDataProcessor.AddLinePreCall(Enum.TooltipDataLineType.SellPrice, function()
    return ns.db.hideSellPrice == true
end)
