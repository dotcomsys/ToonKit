# ToonKit

ToonKit is an add-on for WoW Forever only. The installable code and its notices are in `ToonKit/`. Keep the pinned inputs in `.sources/content/` with the source so the bundled data can be reproduced.

## Build a CurseForge update

1. Update the release version in `ToonKit/Brand.lua` and synchronize `ToonKit/ToonKit.toc` with `tools/Sync-Brand.ps1`.
2. Push to `main` or run **Build ToonKit packages** from the repository’s **Actions** tab.
3. Open the successful run. Its artifact contains the installable ZIP, matching source ZIP, and both SHA-256 checksums.

## Publish from GitHub Actions

1. Under **Settings → Secrets and variables → Actions**, add the repository secret `CURSEFORGE_API_TOKEN` with your CurseForge author API token and the repository variable `CURSEFORGE_PROJECT_ID` with ToonKit’s numeric project ID.
2. Under **Actions → Publish to CurseForge → Run workflow**, keep the branch set to `main`. Enter the numeric run ID from the successful build’s URL and select the CurseForge release type.
3. Check the publishing run’s summary for the CurseForge file ID and corresponding GitHub Releases source ZIP. The workflow verifies both archives, selects WoW Forever 1.60.1, and links the source ZIP from the CurseForge file’s changelog.

Pushes build packages. Publishing starts only when you run the publish workflow. The WoW CurseForge upload API accepts main files only. To link the source for an existing submission, enter the original build run ID and fill in `existing_parent_file_id`. That mode updates the existing file’s changelog and leaves the installable untouched.
