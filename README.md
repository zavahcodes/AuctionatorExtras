# Auctionator Extras

A small companion addon for **Auctionator** with extra features and tweaks.

## Features

- **Hide Blizzard sell price**: removes Blizzard's own "Sell Price:" line from item tooltips, since Auctionator already shows the vendor price.
- **Disenchant value**: on characters that know Disenchant, weapon and armor tooltips get a "Disenchant" line with the expected auction value of the materials the item disenchants into (hold Shift for the list of possible materials). Uses vanilla disenchant tables and Auctionator's scanned prices; shows "?" while a material has no price yet.

Every feature can be toggled on or off on its own.

## Settings

Open the settings with `/aucx` (or `/auctionatorextras`), or go to **Options → AddOns → Auctionator Extras**.

Settings are saved in `AuctionatorExtrasDB`.

## Adding a module

1. Create a file in `Modules/` that calls `ns.RegisterModule{ key, name, defaults, options, OnLoad, Refresh }` (see the spec at the top of `Core.lua`).
2. Add it to `AuctionatorExtras.toc` under `# Modules`.

The options panel builds itself from the registered modules.
