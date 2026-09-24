# Auctioneer for World of Warcraft: Forever (beta)

The Auctioneer addon suite made to run on the **WoW: Forever beta client**. It is
[profdumbbelldore's Auctioneer 12.x fork](https://github.com/profdumbbelldore/Auctioneer-12.x.BETA) (itself a
continuation of [Norganna's Auctioneer](https://auctioneeraddon.com/), official source
[gitlab.com/norganna-wow/auctioneer](https://gitlab.com/norganna-wow/auctioneer), GPL v2 - see `LICENSE`) with the changes the
Forever client needs; the git history keeps the upstream commits. Nothing else is touched: the same nine addon folders, the
same features, the same settings.

Why a separate branch: Forever runs Blizzard's Mainline UI (the retail-style auction house) on the **12.1.5 API set**.
Patch 12.1.5 removed the deprecated item functions that the 12.1.0 build still relies on (`GetItemInfo`,
`GetItemQualityColor`, `GetDetailedItemLevelInfo`, `GetItemIcon`), and the Forever client also has no
`GetMouseFocus`, `MouseIsOver`, `UIParent_OnEvent`, `InterfaceOptionsFrame_OpenToCategory` or `NUM_ITEM_QUALITIES`.
Each of those was a Lua error waiting to happen on Forever; on retail 12.1.0 they still work, which is why upstream
never saw them.

## Install

1. Download the zip from the [Releases](../../releases) page.
2. Copy the nine folders - `!Swatter`, `Auctioneer`, `Auctioneer_Stats_OverTime`, `Auctioneer_Util_DealFinder`,
   `Auctioneer_Util_Valuer`, `Enchantrix`, `Informant`, `SlideBar`, `Stubby` - into
   `World of Warcraft\_classic_beta_\Interface\AddOns\`.
3. Start the game fully. A `/reload` does not pick up new addon folders.

## Beta client bug you will run into: saved settings are not loaded back

Forever beta builds 1.60.1.69913 and later **write** addon SavedVariables but do not **load** them at the next
start ([forever-bugs #34](https://github.com/ClassicWoWCommunity/forever-bugs/issues/34)). Auctioneer's price history
lives in SavedVariables, so until Blizzard fixes the client every scan is forgotten at logout unless you use a
workaround such as [ForeverSVFix](https://github.com/nobewayo/ForeverSVFix). This branch does not work around it
itself; it only makes the addon run.

## What changed

35 files, every change is a small local edit:

* **Item API** - every call to a removed global goes through `C_Item` (`C_Item.GetItemInfo`,
  `C_Item.GetItemQualityColor`, `C_Item.GetDetailedItemLevelInfo`, `C_Item.GetItemIconByID`). In Auctioneer's
  `Items.lua` / `Internal.lua`, the embedded `TipHelper` / `LibAucItemCache` libraries, Informant and Enchantrix.
  Four Enchantrix files with many call sites get a file-scope `local` alias at the top instead of dozens of edits.
* **`NUM_ITEM_QUALITIES`** is not defined on this client - `nTipHelper` falls back to 8.
* **Enchantrix** reads interface number 16001 as "Classic era". That is right for its reagent tables (Forever's
  item pool is the classic one), but it then called the classic-only craft API (`GetNumCrafts`, `GetNumTradeSkills`),
  which Forever does not have. That branch now runs only when those functions exist.
* **`GetMouseFocus`** (gone since 11.0) - the embedded `Configator/ScrollSheet` (column drag in every Auctioneer
  sheet) uses `GetMouseFoci()[1]`.
* **`MouseIsOver`** - the embedded `LibGraph` falls back to `Region:IsMouseOver()`.
* **`UIParent_OnEvent`** - `!Swatter` only calls it if it exists (the call is only reached with Swatter switched off).
* **`InterfaceOptionsFrame_OpenToCategory`** - `/slidebar config` opens the panel through `Settings.OpenToCategory`.
* Five stale embedded copies of `LibRevision` still called `GetAddOnMetadata` / `IsAddOnLoaded`; they now use
  `C_AddOns` like the two copies upstream already updated.
* Every TOC lists `16001`, so the client no longer marks the addons as incompatible.

## How this was checked

Every global the suite reads was listed from the compiled Lua 5.1 bytecode and compared with what the Forever
client actually defines - Blizzard's generated API documentation and UI code for the beta (branch `forever` of
[Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source), build 1.60.1.69977) - and with the removal notes on
[warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes). After the changes every file compiles and
no call to a removed function remains. In-game reports from the beta are welcome in this fork's issues.

---

*Upstream README follows.*

Known issues:

1.) In certain situations, some data will not be present within the crafting window.

2.) Data doesn't appear on item links (not sure if this is something that can be fixed at this time).
