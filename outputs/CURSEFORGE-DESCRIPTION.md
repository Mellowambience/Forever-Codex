# Forever Codex

Kill a mob. Learn something. Make a plan for the next adventure.

I started this because I wanted a bestiary that filled itself as I played WoW Forever. It grew into a personal codex: creatures, loot, professions, and stories from the road, all in one grimoire.

## New in 0.3.20 beta: Today's Page

Open **/fbc** or click the custom crescent grimoire on your minimap. Your opening page gives you three reasons to check in:

- **Earn some coin:** Find the best positive estimated crafting margin among your priced, known recipes. Missing information gets a next step instead of a made-up profit.
- **While you're here:** See creatures recorded in your current zone whose observed loot matches materials missing from your pinned recipes.
- **Your journey:** See discoveries, repeat encounters, quest turn-ins, and items looted since login or reload. Start an editable campfire tale or continue the draft you already have.

The page follows your chosen Codex theme and refreshes while open. Your tale uses recent recorded activity, up to 24 hours; the session summary resets at login or reload.

## What else is inside?

**A bestiary you build by playing.** Confirmed kills unlock creatures of all kinds, with native 3D models, observed stats, abilities, loot, research milestones, bookmarks, and your own notes. Rotate, zoom, pan, or expand the viewer.

**Professions with a purpose.** Read your character's available profession ranks, import known recipes, compare estimated margins in Gold Planner, and pin recipes for material tracking. At the Auction House, **Check prices** looks up the selected recipe's output and materials and refreshes the estimate and shopping list. If automatic lookup isn't exposed by your client, use the native AH search and Recalculate.

**Help deciding what to sell.** Item tooltips compare vendor value with available AH quotes. The assisted auction seller shows eligibility and pricing before you post. It does not sell everything unattended.

**Your own Atlas and Campfire Tales.** Browse recorded creatures and stories by zone. Turn recorded adventures into editable stories with a voice informed by your character's race and class, then share a passage when you're ready.

**A book that feels like yours.** Choose Gothic Aether, Aged Parchment, Moonlit Silver, or Ember and Brass. Windows can be moved, and scroll cues make longer pages easier to spot.

## A few things to know

This is still a beta. It learns from what the game exposes and what you record; it is not a complete database of every mob or hidden stat.

- Observed loot is evidence from loot windows, not a guaranteed drop or a measured drop chance. A creature recorded in your zone is not a live spawn marker. Included reference information is labelled separately.
- Crafting estimates use quotes no more than two days old, the recipe's minimum output, and the configured AH cut. Owned materials still have market value. Deposits, failed listings, and demand are not included, and profit is not guaranteed.
- Your discoveries and imported recipes are saved locally; profession recommendations use recipes known by the current character. Tales are per character. There is no downloader telemetry or cross-player chat service.
- WoW saves progress on logout or reload. The Codex cannot recover adventures from before it was recording.

## Getting started

1. Enable **Forever Codex**, then open **/fbc** or the minimap grimoire.
2. Defeat a creature to start your bestiary.
3. Open **My Professions**, open your profession's recipe window, and choose **Import recipes**.
4. Review a recipe in **Gold Planner**, check its prices at the AH, and pin it. Today's Page can then connect missing materials to observed creature drops nearby in the same zone.
5. After an adventure, choose **Write my tale**. If you already have a draft, **Continue my tale** keeps it safe.

Shortcuts: **/fbc today**, **/fbc bestiary**, **/fbc professions**, **/fbc gold**, **/fbc atlas**, **/fbc tales**, and **/fbc sell**. Right-clicking the minimap icon hides it; **/fbc minimap** brings it back. **/fbc feedback** prepares a report you can copy into CurseForge comments.

## The road to 1.0

These are plans, not promises that everything is already built:

- **Next:** Check the new home-page and recipe-price flow in real gameplay, then investigate a sales ledger using reliable auction-mail evidence.
- **Better field knowledge:** Expand checked Forever creature and loot references, with clear source coverage and more useful material leads.
- **Better profession decisions:** Improve recipe-import coverage and explain missing prices, costs, and unavailable information more clearly.
- **Before 1.0:** Focus on readability, large collections, long sessions, character switching, saved-data upgrades, and compatibility. Then publish a release candidate before calling the core stable.

The goal is a codex worth opening while you play, not a pile of tabs or a promise to make everyone rich overnight. If something feels confusing or breaks, let me know what you were doing. That helps shape the next patch.

Built for **World of Warcraft Forever 1.60.1 / Interface 16001**. Unofficial and not affiliated with Blizzard Entertainment. Creature models come from your installed client; they are not bundled in the addon.
