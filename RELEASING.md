# Releasing Forever Codex

1. Update F.version, both identical TOCs, addon README and CHANGELOG.
2. Update outputs/CURSEFORGE-DESCRIPTION.md with current behavior, limitations and a realistic roadmap. Mirror the player-facing copy in README.md; retain source/release guidance at the end.
3. Run `python work/check_release.py`. Describe any outstanding live-client checks honestly.
4. Run `python work/package_release.py`. It checks documentation/version agreement and builds a ZIP containing only the ForeverBestiary addon directory, including Media assets.
5. Install to the existing WoW Forever AddOns folder and verify file hashes. Do not touch saved variables.
6. Push source, tests, docs and tag to GitHub. Publish the ZIP as a beta prerelease while the addon is beta.
7. Update the live CurseForge description from outputs/CURSEFORGE-DESCRIPTION.md. Upload the ZIP for Forever 1.60.1, choose Beta, include the current changelog, and publish automatically after approval.
8. Verify the saved description and submission status. Record the file ID, package hash and remaining live checks in outputs/PUBLISHING.md. Report Pending/Processing honestly.
9. Retain the newest package, a rollback version and any package awaiting approval. Remove superseded local ZIPs only within the outputs directory.
