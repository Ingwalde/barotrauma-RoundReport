# Workshop release preparation

- Title: **Round Report**
- Version: **0.4.0**
- Required Workshop item: **Lua For Barotrauma**, ID `2559634234`
- Preview: repository `preview.png` (English illustrative render)
- Description: paste `docs/workshop-description.txt` (Steam BBCode)
- Change note: `Initial test release: multiplayer crew statistics, MVP debrief, session totals and automatic localization.`
- Suggested first upload visibility: Private until a complete gameplay round is verified.

## Build

Run `python tools/package_workshop.py` from the repository. No third-party packages
are required. It produces a unique directory under ignored `dist/` containing:

- `RoundReport/`: only manifest-listed Lua files, `filelist.xml`, `preview.png`, and `LICENSE`.
- `RoundReport-0.4.0.zip`: the same folder for distribution/backup.
- `SHA256.json`: per-file checksums, outside the upload folder.

Tests, Git metadata, saves, configuration backups and development scripts are not
included. Use the generated folder as the publishing source; the ZIP is not the
game's upload input. Keep the description and checksums outside the upload folder.

## Publish through Barotrauma

The official [publishing guide](https://regalis11.github.io/BaroModDoc/Intro/Publishing.html)
describes the **Publish** tab in the modding menu. Select the local Round Report
package, supply the description, English preview, available relevant tags, change
note and visibility, then publish using the owner's Steam session. Steam may show
its agreement prompt; the account owner must handle it.

Add Lua For Barotrauma under **Required Items** on the resulting Workshop page and
record the new item URL here. Retain the Workshop ID produced by the game for
subsequent updates; do not create a new listing each time.

Only enable one copy of Round Report when testing the Workshop subscription; the
game can retain both a local and a subscribed copy after publication.

## Validation status

The architecture and localization builds pass 27 automated tests and the server
smoke harness. The earlier native lobby test covered report delivery, MVP, tabs,
layout bounds and close/reopen. The latest architecture still needs a complete
native gameplay round. The English preview was visually inspected.

Publication has not been performed; there is no Workshop item URL yet.
