# Forever Codex workspace

Target WoW Forever 1.60.1 / Interface 16001. Addon source is outputs/ForeverBestiary; preserve the legacy folder and saved-variable names.

Every release must update outputs/CURSEFORGE-DESCRIPTION.md, README.md, addon README.md and CHANGELOG.md to reflect actual shipped features and remove stale roadmap claims. Update the live CurseForge description as part of publishing, and verify it saved. Do not claim a submission is approved until CurseForge shows approval. The user has asked that descriptions stay current from now on.

Run the release checks via python work/check_release.py. Keep source/test changes together. Do not include game saved variables, credentials, user reports, or historic work scripts in public commits. Keep only recent rollback release ZIPs locally. See RELEASING.md.
