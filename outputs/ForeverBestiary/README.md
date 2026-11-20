# Forever Codex 0.3.20 beta

## Today's Page

/fbc and the minimap open your parchment home page. Earn some coin highlights the best positive margin among your priced, known recipes. While you're here matches missing pinned-recipe materials to observed creature drops in your current zone. Your journey summarizes activity since login/reload and opens an editable tale based on recent recorded events (up to 24 hours), preserving any existing draft. The page refreshes while open. /fbc bestiary opens creature browsing directly.

## Professions and Gold Planner

Open My Professions with /fbc professions or Gold Planner with /fbc gold. Open your profession and select Import recipes to populate the planner. At the Auction House, choose a recipe and click Check prices to refresh its output and material quotes. The estimate and shopping list update when the search finishes. Recalculate also picks up manual searches and changed bag contents. Estimates value all materials at market price and use the recipe's minimum output after the configured AH cut. Buy cost covers only the missing materials in your bags. Estimates omit deposits and demand. Pin recipes to track materials. /fbc feedback prepares a copyable report.

## Install and open

Extract the ZIP so `ForeverBestiary` sits directly inside `_forever_/Interface/AddOns`. Enable it in the AddOns list. Restart the client if a newly installed addon is not listed. Type `/fbc` or click the minimap book button.

Your first confirmed creature kill adds an entry. Further kills advance milestones at 5, 15, and 30. Group kills count by default. Targeting or previewing a creature does not discover it.

## Features

- Native 3D creature viewer with drag rotation, broad camera-distance zoom, aspect-aware fit, right-drag vertical pan, reset, and target preview. Camera distance/pan are remembered per discovered creature.
- Search by name, type, and zone; combine type, zone, level, profession and research menus; bookmark favorite entries.
- Overview, Abilities, Loot, Professions, Crafting, Research, and Notes tabs.
- Available observed level, habitat, classification, health, base armor/damage, attack speed, and level/classification variants. Restricted or ambiguous values stay unavailable.
- Successful NPC spell observations when the client exposes them.
- Account-wide discoveries, character kill counts, encounter dates, personal notes, and saved window/minimap positions.
- Source-attributed loot observations with session deduplication.
- Skinning detection when the successful cast and following source-linked loot are both accessible. Manual skinning and salvage confirmations.

The Codex dismisses its windows when combat begins. Open it again after combat. Dragging places a window where you drop it. Use `/fbc resetpos` to return the journal to automatic placement.

Use **Theme** in the Bestiary or Campfire Tales to switch both chapters. **Gothic Aether** is the default, with violet ink, lavender headings, and blue accents. **Aged Parchment**, **Moonlit Silver**, and **Ember and Brass** offer different paper and ink palettes. The Codex remembers your choice after reload.

## Controls

| Control | Action |
|---|---|
| `/fbc` or `/bestiary` | Open/close |
| `/fbc target` | Preview current target without discovery |
| `/fbc minimap` | Show/hide minimap button |
| `/fbc notify` | Toggle discovery messages |
| `/fbc group` | Toggle group vs personal/pet kill credit |
| `/fbc resetpos` | Recenter the journal |
| `/fbc debug` | Show collector status |
| `/fbc report` | Open a copyable report for the current session |
| `/fbc safe` | Toggle auction and tooltip isolation for the next reload |
| `/fbc tale` | Open Campfire Tales |
| `/fbc atlas` | Browse your discoveries by zone |
| `/fbc tale note <text>` | Add a field note while travelling |
| Minimap left-click | Open/close |
| Minimap right-click | Hide button |
| Drag minimap button | Reposition |

Type/research filter buttons cycle through options. Clear filters resets both. Scroll over the creature list to browse long collections.

In the model viewer, scroll or use + / - to zoom, left-drag to rotate, and right-drag to pan vertically. Fit or Reset model restores default framing. Zoom percentages are relative to the fitted view; deliberate close-ups can crop the creature, and Fit returns to the overview.

## Atlas

Open **Atlas** in the Bestiary or type `/fbc atlas`. **Here** opens your current zone. Pick a creature to open its Bestiary entry. **Encounter map** opens the map at a recorded player location from that zone, when available. Tracked creatures appear first.

The activity page shows recent recorded loot, quests, visits, and notes for that zone. Click **Refresh** to pick up new activity. The Stories tab links stories written with this build to the zones in their source records. Earlier stories remain available in Campfire Tales.

## Campfire Tales

Open **Campfire Tales** from the journal or type `/fbc tale`.

1. Click **Write story**. The Codex drafts a first-person story from your recent play, with phrasing informed by your character's race and class.
2. Edit the draft directly on the page. Click **Save story** to keep it under **Saved stories**.
3. Click **Share in chat** to select and copy short passages for retelling.

**Activity** shows zone visits, credited creature encounters, confirmed quest turn-ins, personal loot, and field notes as you play. It shows up to 60 recent entries from the last 24 hours. From Activity you can also see the original events behind a draft or saved story. Recovered Bestiary encounters show their source. Add a note in the window or type `/fbc tale note <text>` to record a detail in your own words. Drafts and saved stories belong to the character who wrote them.

## Data and limits

This is an observation journal, not a preloaded complete creature database. Forever may restrict enemy identity, stats, and spell values. The journal skips those values and never fabricates them. The live client currently leaves many enemy combat stats unavailable. Stats that can be observed may vary with buffs and context. Research milestones mark progress and do not hide available observations behind kill requirements.

Loot counts describe items seen, not necessarily acquired; they are not drop rates. Reopening a source/item is deduplicated within the current session. Recipe links, automatic gathering beyond supported skinning observations, authoritative resistance/weakness tables, global creature completion totals, and complete appearance catalogs are not included.

Creatures outside target/mouseover/nameplate observations can initially appear as `Creature <ID>` after group credit. Models depend on what the client can resolve. Player pets are not cataloged as wild creatures.

SavedVariables are shared within the same local WoW account data scope. They are written to disk by the game on logout/reload. No cloud service is used. The addon cannot recover kills from before it was enabled. Upgrading from 0.1 preserves discoveries and notes.

## Validation

Earlier live checks covered the journal, minimap button, native models, and saved discoveries. Lua 5.1 checks cover migration, kill credit, deduplication, restricted values, observations, filters, notes, journal tabs, and minimap controls. Campfire Tales has automated coverage for recording, draft and archive persistence, retelling excerpts, and combat dismissal. Its layout and controls still need a live Forever check.

Unofficial addon, not affiliated with Blizzard Entertainment. No game models or UI textures are bundled; the game renders its own assets.


## Loot sale comparison

The Loot tab shows vendor value per item and an AH listing guide from your own recent auction searches. It records native search results. Find prices in the seller requests quotes only for missing/stale, unprotected bag loot, up to 20 item types per pass. It never queries the entire AH. Optional Auctionator prices are used when that addon provides a newer dated quote. No external price service is required.

Choose a 5% or 15% AH cut to match the auction house you use. Net proceeds assume a successful sale; deposits, failed listings, and demand are excluded. Prices older than two days get a refresh notice instead of a recommendation. Prices are base-item estimates, so equipment variants and an individual item's binding can differ. Bind-on-pickup and quest-bound items are marked as normally untradeable. Use Find prices in the seller, or search the item normally at the AH, to fill missing quotes. The cache is limited to 1,000 items and seven days, isolated by realm and faction.

This build also previews expanded models, encounter-vicinity maps, known-recipe tracking and a small partial reference pack. Native profession and auction capture testing are still pending; this is not the 1.0 release.

## Auction selling

Run `/fbc sell` (or choose Auction seller in Loot). The seller also opens when you visit an Auction House. It automatically prepares a queue of recorded loot in your current bags. Choose match price or undercut by 1%, a stack quantity, 12/24/48 hours, a minimum unit price, and a maximum deposit. Choose the AH cut that applies to your auction house. Use Post next for each posting; if the game requires a price confirmation, the button changes to Confirm price. No unattended posting, purchases, or auction cancellation is performed. Price lookups are serialized and respect the game throttle.

Tracked items, pinned-recipe ingredients, bookmarked creature loot and your Keep list are protected. Known-recipe materials are also protected by default; that preference can be changed in the seller. Equipment, battle pets, uncommon-or-better items, quest items, bound/locked items and unknown trade states are kept. Keep/Unkeep is available beside each loot entry and in the seller. Only current bag stacks are offered, not bank or equipped items.

Prices must be no older than two days. Missing prices switch the main button to Find prices. After quotes load, it changes to Post next. Items with no listings remain skipped. The queue skips auctions that do not beat vendor value after commission and the possible deposit loss. Rules are saved; every post rechecks the current bags, price and protections. Posting stops on errors and waits for the game before accepting another request. Close the AH to stop the flow. A request without a response can be cleared with Refresh queue after 15 seconds.

This path uses Forever's supported C_AuctionHouse posting APIs. Unsupported clients show an explanation and leave posting to the native AH. Local posting/confirmation tests pass; live AH posting still needs validation before public release.

## Window behavior

Only one bestiary workspace is shown at a time. Auction seller replaces the codex; Back to codex returns to the same journal page. The expanded viewer replaces the journal and returns to it when closed. Selection, notes and camera settings are preserved.

The narrower seller docks alongside the native Auction House, with extra options behind Selling rules. Bestiary windows fit around visible auction, profession, bank, merchant, mail, character, map and bag panels. Native panels are never moved or closed. If a crowded or fullscreen layout leaves no readable space, the requested bestiary window temporarily tucks away and returns when room becomes available. Closing a bestiary window explicitly keeps it closed. Layout adapts to screen/UI scale and visible panel changes. Title bars remain draggable; the codex keeps its saved position, while viewer/seller drags are remembered for the session.

Loot, sale and recipe rows grow with wrapped text. Menus close when switching windows or clicking outside. The current layout has local geometry/transition tests; native AH, bags and fullscreen transitions still need a safe in-game check.

## Item price tooltips

Bag, loot, link and auction seller tooltips show the last-seen AH asking quote and age, suggested unit listing under your match/undercut rule, vendor value and net after your selected cut. A quote from the current AH search is labelled separately from cached quotes. Missing, stale and empty-listing results are explicit. Asking prices are not completed-sale values; deposits, demand, binding and equipment variants still matter.

Fixed the empty-price dead end behind Nothing eligible: the primary action now finds quotes for otherwise eligible bag loot before offering Post next. Protected items remain protected. Other no-eligibility states list concrete reasons instead of a generic failure. Hover a seller row for the item and price tooltip. Successful server posting still requires native validation; local tests now cover the complete missing-price, search-result, eligible-item and posting-call sequence.
