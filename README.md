# Auctionator Extras

A small companion addon for **Auctionator** with extra features and tweaks.

## Features

- **Hide Blizzard sell price**: removes Blizzard's own "Sell Price:" line from item tooltips, since Auctionator already shows the vendor price.
- **Disenchant value**: on characters that know Disenchant, weapon and armor tooltips get a "Disenchant" line with the expected auction value of the materials the item disenchants into, plus the icon and chance of each possible material next to the label (can be turned off); hold Shift for the full list with amounts and prices. Uses vanilla disenchant tables and Auctionator's scanned prices; shows "?" while a material has no price yet.
- **Tooltip spacing**: a small gap (size adjustable) above and below the price lines (Vendor, Auction, ..., Disenchant) so they stand apart from the rest of the tooltip.
- **TSM prices**: imports TSM Desktop's AuctionDB prices (Market Value by default; Min Buyout, Recent, Historical or Region Market Value selectable) into Auctionator's price database, so every Auctionator price comes from TSM. Runs on login/reload when TSM has newer data, and on demand with `/aucx import`, the options button, or Auctionator's scan button (which becomes "Import TSM"). Auctionator's own AH scanning (full scan, autoscan and saving prices while browsing) is turned off while this is on. TradeSkillMaster does **not** need to be enabled: it only needs the TSM Desktop app and the `TradeSkillMaster_AppHelper` folder installed (enabled or not). The addon's `.toc` loads `../TradeSkillMaster_AppHelper/AppData.lua` directly and decodes it itself, so no link or copy is needed. TSM is optional: if there is no TSM data for the character (AppHelper not installed, or no data for that realm), this feature stays out of the way and Auctionator scans and saves prices as usual.

Every feature can be toggled on or off on its own.

## Settings

Open the settings with `/aucx` (or `/auctionatorextras`), or go to **Options → AddOns → Auctionator Extras**. `/aucx import` forces a TSM price import.

Settings are saved in `AuctionatorExtrasDB`.

## Adding a module

1. Create a file in `Modules/` that calls `ns.RegisterModule{ key, name, defaults, options, OnLoad, Refresh }` (see the spec at the top of `Core.lua`).
2. Add it to `AuctionatorExtras.toc` under `# Modules`.

The options panel builds itself from the registered modules.
