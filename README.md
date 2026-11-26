# ToonKit

ToonKit is an add-on for WoW Forever only. The installable code and its notices are in `ToonKit/`. Keep the pinned inputs in `.sources/content/` with the source so the bundled data can be reproduced.

## Build a CurseForge update

1. Update the release version in `ToonKit/Brand.lua` and synchronize `ToonKit/ToonKit.toc` with `tools/Sync-Brand.ps1`.
2. Push to `main` or run **Build ToonKit packages** from the repository’s **Actions** tab.
3. Download the artifact from the completed run and extract it. It contains the installable ZIP, matching source ZIP, and both SHA-256 checksums.
4. Upload the installable ZIP to CurseForge as the main file and attach the matching source ZIP to that release. Use the applicable WoW Forever game version and select **Alpha** for the 0.10 Alpha build.

The workflow builds the files for manual upload. It requires no CurseForge credentials.
