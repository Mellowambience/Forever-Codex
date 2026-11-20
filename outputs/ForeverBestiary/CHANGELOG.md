# 0.3.20 beta

- Open Today's Page from /fbc or the minimap: review a priced crafting opportunity, observed creature drops for missing pinned-recipe materials in your zone, and your current session's journey.
- Start or continue a Campfire Tale without replacing an existing draft. Use /fbc bestiary for direct creature browsing.
- Add a custom crescent grimoire minimap icon and a parchment home page that follows all four Codex themes.
- Includes the 0.3.19 Gold Planner Check prices flow; improve combat cancellation messages.
- Refresh the description and roadmap to match the current addon.

# 0.3.19 beta

- Add Check prices to Gold Planner. Look up the selected recipe output and materials at the Auction House, then refresh its estimate and shopping list.
- Show price-search progress and recovery messages for empty listings, timeouts, and closing the AH.

# 0.3.18 beta

- Show overflow cues on long menus and scrollable Codex panels.

# 0.3.17 beta

- Calculate margins using minimum recipe yield. Guide players through importing recipes and finding missing prices.

# 0.3.16 beta

- Remove Party Chat. Add Gold Planner recipe margins, shopping lists, and recipe pinning.

# 0.3.15 beta

- Drag Party Chat, My Professions, and Feedback by the title bar.
- Choose a profession to see skill, recorded recipes, and Cooking rank guidance.

# 0.3.14 beta

- Replace forum topics with a single party chat and a streamlined composer.
- Add My professions with readable ranks and manual sharing in chat.

# 0.3.13 beta

- Add opt-in live party topics and replies.
- Prepare loot posts from the Bestiary and feedback reports for manual sharing.
- Search creatures and stories in the selected Atlas zone.

# 0.3.12 beta

- Add the Atlas with recorded creatures, recent activity, and saved stories grouped by zone.
- Jump to your current zone, open a creature's Bestiary entry, or view a recorded encounter on the map.
- Bring tracked creatures to the top of each zone's list and highlight them as field leads.
- Includes the simpler Campfire Tales controls and all four Codex themes.

# 0.3.11 beta

- Add the Gothic Aether default with violet ink, luminous blue accents, and gothic display headings where the client font supports them.
- Switch between Gothic Aether, Aged Parchment, Moonlit Silver, and Ember and Brass from either chapter. The chosen theme applies to both and is saved with Codex settings.

# 0.3.10 beta

- Open Campfire Tales on the Story page with a clear Write story action. Save stories and share short passages directly from the story view.
- Group recent activity and a story's source events under Activity. Saved stories and the current draft remain accessible from the sidebar.

# 0.3.9 beta

- Warm the Bestiary and Campfire Tales pages to aged tan parchment. Add stronger binding, page edges and grimoire details.

# 0.3.8 beta

- Give Campfire Tales an in-character voice informed by your race and class, with occasional quips tied to recorded events.
- Record confirmed quest turn-ins and use the player's current zone for live encounter entries.
- Restyle the Bestiary and Campfire Tales as a bound codex, with parchment pages and antique-gold accents.

# 0.3.7 beta

- Write short first-person stories that follow the journey by location, fold repeat encounters into a single passage, and work field notes into the retelling.
- Open new drafts in The Tale. Rewrite draft replaces a working draft only after confirmation. Save draft keeps a copy in the archive.

# 0.3.6 beta

- Show a Live Record that updates as you play and stays accessible before you create a draft.
- Capture credited repeat encounters. Recover recent Bestiary encounters when the saved character counts support attribution.
- Preserve the original event list attached to drafts and saved tales.

# 0.3.5 beta

- Open Campfire Tales from the Codex or with `/fbc tale`.
- Turn recent zone visits, first creature discoveries, personal loot, and field notes into an editable first-person tale. The Record shows the events used for the draft.
- Keep a draft and save tales to a per-character archive. Retell offers short, selectable passages you can copy into chat yourself.

# 0.3.4 beta

- Close Codex windows when combat begins and restore the model when the journal next opens.
- Keep manually moved windows at their dropped positions.
- Add /fbc report for copyable session diagnostics and /fbc safe for isolating auction features and Codex item tooltips after reload.
- Guard incomplete saved stats, recipe records, native frame geometry, optional tooltip hooks, and auction post and confirmation methods.
- Coalesce repeated stat and profession queries. Accumulate ability counts across separate creature spawns.
- Protect newer-format saves from restoration with an older backup.

# 0.3.3 beta

- Renamed the addon to Forever Codex. Bestiary remains the name of the creature journal. Existing discoveries, settings, and slash commands carry over.

# 0.3.2 — November 10, 2026 beta

- Loot and auction seller lists fit more items on screen. Loot rows show observed counts, bag quantities and a short price comparison. Hover for detailed AH prices and recommendations.
- Find prices fills missing quotes for eligible loot. The seller distinguishes empty searches from results without a readable buyout.
- The beta includes the expanded creature viewer, new journal filters, migration backup, partial loot references, recipe tracking preview and Auction House seller.
- Built for WoW Forever 1.60.1. Live auction posting is still being verified.

# 0.3.1 — Roadmap implementation beta

- Fixed the empty-quote dead end: Find prices loads missing/stale prices for eligible bag loot (20 item types per pass, serialized and throttled), then hands off to Post next. Empty listings and kept-item reasons stay explicit.
- Added vendor, current/last-seen AH quote, suggested listing and after-cut proceeds to item tooltips, including seller rows; no fabricated live prices.

- Reworked window coordination: one bestiary workspace at a time, compact Auction seller with collapsible rules, automatic placement around native panels/bags, readable scaling, temporary suspension on crowded screens, viewer return navigation, and text-aware row heights. Native layout checks remain pending.

- Added the Auction seller: automatic eligibility/price queue, match or 1% undercut, duration/stack/minimum/deposit rules, persistent Keep list, protected tracked/recipe/bookmarked loot, game-click posting and native confirmation handling. Open with /fbc sell or at an Auction House. Live posting validation remains pending.

- Added an expanded model viewer and camera settings that adapt when moving between the journal and expanded view.
- Added schema validation, a persistent pre-migration backup, guarded backup restore, and read-only handling for newer-format saves.
- Replaced cycling filters with selectable menus; added zone, level, profession, research, bookmark and tracking filters, plus sorting.
- Added a dedicated Loot tab with item icons/tooltips, observed counts, uniquely source-matched personal confirmations, partial prior reference reports, item filters and tracking.
- Improved repeat/partial loot handling with a bounded source ledger retained across reloads.
- Added a Crafting preview for accessible known recipes, ingredient counts from current bags, recipe links and pinned recipe requirements. This part still needs live profession testing.
- Added encounter-vicinity map links, bounded recent encounter history, zone research, tracked creatures/items and addon-local mastery badges.
- Added clearer observed/restricted/reference labels and client-build provenance.
- Included a pilot reference pack with six NPCs and 14 source/item observations from this addon's prior in-game records. These are partial reports, not complete server loot tables; no reference drop chances are included.
- Increased usable journal space on larger screens and kept a compact height on smaller screens.

This beta implements the early roadmap and previews later systems. It is not 1.0. Broad reference coverage, verified drop rates, full profession coverage, appearance catalogs, curated lore, and release-candidate playtesting remain unfinished.

# 0.2.1 — Creature viewer hotfix

- Replaced the limited portrait zoom with camera-distance zoom over a much wider range.
- Added aspect-ratio-aware default framing to give tall creatures and wings more room.
- Added Fit, +, and - controls with a relative zoom percentage.
- Added right-drag vertical panning and per-creature saved camera distance/pan.
- Reset model now resets the camera and panning without unnecessarily reloading the creature.
- Apply the initial framing after the native model finishes loading.

# 0.2.0 — Initial public beta

- Added native journal tabs for stats, abilities, professions, research, and notes.
- Added the draggable minimap book button, tooltip, saved angle, right-click hide, and slash-command restore.
- Corrected minimap icon sizing and native border alignment.
- Added bookmarks, creature-type and research filters, character kill counts, and level/classification observations.
- Added observed successful NPC spell casts, with restricted-value checks and cast deduplication.
- Added source-linked skinning observations when the cast and resulting loot are accessible; manual skinning and salvage confirmations remain available.
- Improved item/source loot aggregation and session deduplication, including multiple slots for the same item.
- Added model rotation, zoom, reset, and live-target preview without discovery credit.
- Preserved existing discoveries and notes through schema migration. Saved journals now select an entry correctly on opening.
- Bounded temporary caches and added controls for notifications, group kill credit, and window recentering.

Initial limitations: this is a local observation journal, not a complete creature database. Client restrictions can hide combat stats and abilities. Recipe links, reliable weaknesses and resistance tables, and automatic gathering beyond supported skinning observations are not included. Loot counts mean items seen, not confirmed acquisition or drop rates.
