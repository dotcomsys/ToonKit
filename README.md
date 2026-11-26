# ToonKit

ToonKit is an add-on for WoW Forever only. The installable code and its notices are in `ToonKit/`. Keep the pinned inputs in `.sources/content/` with the source so the bundled data can be reproduced.

## Build a CurseForge update

1. Update the release version in `ToonKit/Brand.lua` and synchronize `ToonKit/ToonKit.toc` with `tools/Sync-Brand.ps1`.
2. Push to `main` or run **Build ToonKit packages** from the repository’s **Actions** tab.
3. Open the successful run. Its artifact contains the installable ZIP, matching source ZIP, and both SHA-256 checksums.

## Publish from GitHub Actions

1. Under **Settings → Secrets and variables → Actions**, add the repository secret `CURSEFORGE_API_TOKEN` with your CurseForge author API token and the repository variable `CURSEFORGE_PROJECT_ID` with ToonKit’s numeric project ID.
2. Under **Actions → Publish to CurseForge → Run workflow**, keep the branch set to `main`. Enter the numeric run ID from the successful build’s URL and select the CurseForge release type.
3. Check the publishing run’s summary for the two CurseForge file IDs. The workflow verifies both archives, selects WoW Forever 1.60.1, and attaches the source ZIP to the installable ZIP.

Pushes build packages. Publishing starts only when you run the publish workflow. You can also download the artifact to upload both files manually. If the installable upload succeeds and the attachment fails, check the parent file’s attachments. If the source is missing, run the workflow again with the same build run ID and fill in `existing_parent_file_id` with that parent file ID. This uploads only the source ZIP.
