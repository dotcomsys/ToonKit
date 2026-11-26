Current production icon: ToonKit-master-v2.png. See Icon-v2-prompt.md for the built-in generation prompt. ToonKit-master.png is the preserved first version. Runtime conversion uses v2.

# ToonKit identity

Original icon generated with the built-in imagegen tool on 2026-10-18 for this project. The editable production master is ToonKit-master.png. Media/ToonKit.tga is an uncompressed 256 x 256 BGRA conversion for the WoW client. Brand.lua is the runtime identity; Sync-Brand.ps1 synchronizes TOC icon metadata. No Blizzard or other addon logo was copied.

Prompt: Create one finished square game-addon brand icon for ToonKit, an independent classic fantasy MMO character adventure companion. Sturdy brown leather adventure journal, bronze corner fittings, bold T-shaped brass clasp, tiny pale arcane-blue compass star, ivory parchment edges, hand-painted classic fantasy inventory-icon craft. Centered frontal three-quarter view, legible at 32 pixels, bevelled bronze square frame, dark warm charcoal interior, opaque background. No copied Warcraft logo, no extra text, no mockup or sheet.

Reproduce the client format from the project root:

```powershell
ffmpeg -i Branding/ToonKit-master.png -vf scale=256:256 -pix_fmt bgra -c:v targa -rle 0 ToonKit/Media/ToonKit.tga
```

Full built-in prompt: Create one finished square game-addon brand icon for ToonKit, an independent classic fantasy MMO character adventure companion. Original identity: a sturdy closed brown leather adventure journal with bronze corner fittings, a single bold embossed T-shaped brass clasp, a small luminous pale arcane-blue compass star inset in that clasp, ivory parchment page edges, rich hand-painted early-2000s fantasy game inventory-icon craft. Frontal three-quarter view, centered, extremely legible silhouette at 32 pixels, thick bevelled antique bronze square outer frame with clipped corners, dark warm charcoal interior, fully opaque icon filling canvas. Restrained warm gold and tiny arcane blue, no text, no extra symbols, no copied Warcraft logo, no letters apart from abstract T-shaped clasp, no mockup, no multi-icon sheet. Render as a polished production icon, 1024 square.
