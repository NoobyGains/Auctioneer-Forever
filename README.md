# Auctioneer for World of Warcraft: Forever

The Auctioneer addon suite made to run on the **WoW: Forever client**. It is
[profdumbbelldore's Auctioneer 12.x fork](https://github.com/profdumbbelldore/Auctioneer-12.x.BETA) (itself a
continuation of [Norganna's Auctioneer](https://auctioneeraddon.com/), official source
[gitlab.com/norganna-wow/auctioneer](https://gitlab.com/norganna-wow/auctioneer), GPL v2 - see `LICENSE`) with the changes the
Forever client needs; the git history keeps the upstream commits. The same nine addon folders, the same features, the
same settings - plus fixes for bugs and slow spots that get in the way of using it on Forever (see
[Changes beyond the port](#changes-beyond-the-port) and [ADR 0001](docs/adr/0001-fork-scope-beyond-port.md)).

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
   `World of Warcraft\_forever_\Interface\AddOns\`.
3. Start the game fully. A `/reload` does not pick up new addon folders.

Saved settings and price history persist between sessions: the beta bug that kept SavedVariables from loading
([forever-bugs #34](https://github.com/ClassicWoWCommunity/forever-bugs/issues/34)) was fixed in build 70009, so
ForeverSVFix is no longer needed.

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

## Changes beyond the port

* **Faster scans: no wait for item key info.** Prices are recorded straight from the browse results. The scan used
  to stop on every item until its item key info (name, icon, quality) arrived from the server (up to 1s each); that
  is now fetched only when an item is shown, and the Deal finder and the Valuer redraw when it arrives.
* **Faster scans: paging by the throttle.** The next page of results is requested as soon as the client allows it
  (`AUCTION_HOUSE_THROTTLED_SYSTEM_READY`), instead of after a fixed 0.4s pause per page.
* **Scan edge cases.** A scan with a single result now reaches the statistics; closing the auction house mid-scan
  keeps the pages already received; a new scan started while statistics are still being saved is no longer cut
  short; a scan with no results completes.
* **Tooltip prices for item links and crafting reagents.** The tooltip built the item key with the item's own level
  (e.g. 5 for Linen Cloth), while scans record level 0 for items the auction house does not group by level, so the
  lookup missed ("No statistics for this variant"). Links now use the same key a scan records.
* **Tooltip prices for random-suffix items** ("of the Bear", "of the Falcon"...). Scans record each variant
  separately, but a modern item link does not carry the suffix the auction house keys it by, so these never showed a
  price. Scans now remember each item's variants, and the tooltip finds the linked one by name. On the first hover,
  while the variant names are still arriving from the server, it shows the price range across the variants that
  have a price.
* **Faster statistics saving.** After a scan, statistics are saved in as many blocks per frame as fit in about 8ms,
  instead of one block per frame plus a fixed 0.5s pause.
* **Scan time, measured in game** on the same empty search (~9900 results, 19 pages): 35.3s before, 14.3s now
  (item key info wait 14.1s → 0s, paging 17.4s → 14.2s, statistics 3.8s → 0.1s).
* **Deal finder and statistics fixes.** The Deal finder no longer throws a Lua error when an item has more than one
  statistic or a statistic without a price, and it flags items below their vendor price again (for items the client
  has cached). `Auctioneer:Statistics()` accepts an item key given as a plain item number (e.g. `2589`).
* **Debug log.** `/run AuctioneerLocal.debug = true` turns it on; `/run AuctioneerLocal.debug = false` turns it off
  (the setting persists per character). Lines show live in Blizzard's Event Trace window (`/etrace`), next to the
  auction house events, and the last 2000 are saved in `AuctioneerLog` inside
  `WTF\Account\<ACCOUNT>\SavedVariables\Auctioneer.lua` on `/reload` or logout. With debug on, each scan logs one
  timing line, also printed to chat:
  `Auctioneer scan: <n> results | fetch <s>s | process <s>s | stats <s>s`; each tooltip logs the item key it looked
  up, once per link.

## Running the tests

The specs load the real addon files against a stubbed WoW API with a virtual clock and a fake auction house. They
run with [busted](https://lunarmodules.github.io/busted/) on Lua 5.1 in Docker (Docker in WSL on Windows):

    wsl.exe -e sh spec/run.sh

`spec/` is not part of the install; copy only the nine addon folders.

## How this was checked

Every global the suite reads was listed from the compiled Lua 5.1 bytecode and compared with what the Forever
client actually defines - Blizzard's generated API documentation and UI code for the beta (branch `forever` of
[Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source), build 1.60.1.69977) - and with the removal notes on
[warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes). After the changes every file compiles and
no call to a removed function remains. The API was re-checked against the released client (Gethe/wow-ui-source
`forever`, build 1.60.1.70862). In-game reports are welcome in this fork's issues.

---

*Upstream README follows.*

Known issues:

1.) In certain situations, some data will not be present within the crafting window.

2.) Data doesn't appear on item links (not sure if this is something that can be fixed at this time).
