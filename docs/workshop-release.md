# Workshop release preparation

- Title: **Round Report**
- Version: **0.5.0**
- Required Workshop item: **Lua For Barotrauma**, ID `2559634234`
- Preview: repository `preview.png` (English illustrative render)
- Description: paste `docs/workshop-description.txt` (Steam BBCode)
- Change note: `Version 0.5.0: per-campaign persistent totals, configurable MVP weights and penalties, and the !rrversion diagnostic command.`
- Workshop page language: **English**
- Suggested visibility: **Public**

## Build

Run `python tools/package_workshop.py` from the repository. No third-party packages
are required. It produces a unique directory under ignored `dist/` containing:

- `RoundReport/`: only manifest-listed Lua files, `filelist.xml`, `preview.png`, and `LICENSE`.
- `RoundReport-0.5.0.zip`: the same folder for distribution/backup.
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

Workshop item: <https://steamcommunity.com/sharedfiles/filedetails/?id=3824014163>
(ID `3824014163`).

Only enable one copy of Round Report when testing the Workshop subscription; the
game can retain both a local and a subscribed copy after publication.

## Validation status

Version 0.5 passes 35 automated tests and the server smoke harness. Version 0.4 was
manually verified in-game through a complete multiplayer round, including report
delivery and interaction. The new persistence and scoring synchronization still
need native verification. The English preview was visually inspected.

Published on Workshop as of 0.5.0: <https://steamcommunity.com/sharedfiles/filedetails/?id=3824014163>.
Update the description and change note there for every subsequent version bump.

## Automated publishing (manual trigger)

`.github/workflows/publish-workshop.yml` packages the mod and uploads it to the Workshop item
above via `steamcmd`. It only runs when triggered by hand (Actions tab → "Publish to Steam
Workshop" → Run workflow) — never on push or merge, so a native verification round still happens
before anything goes live.

One-time setup, done locally by the account owner (not in CI):

1. Install `steamcmd` and log in once interactively as the account that owns this Workshop item:
   `steamcmd +login <username> <password>`. Approve the Steam Guard prompt (email or mobile code)
   when asked. This writes a login session under `~/Steam/config`.
2. Archive that session: `tar -czf steam-config.tar.gz -C ~/Steam/config .`, then base64-encode it
   and store it as the repository secret `STEAM_LOGIN_CACHE_B64`. Treat this file like a password —
   it lets steamcmd log in without the 2FA prompt.
3. Add `STEAM_USERNAME` and `STEAM_PASSWORD` as repository secrets too (steamcmd still wants them
   alongside the cached session).
4. Re-do step 1–2 if the session ever expires or Steam invalidates it (login failures in the
   workflow log are the symptom).

This upload path (`steamcmd +workshop_build_item`) has not been exercised against this item yet —
treat the first run as a test and confirm the Workshop page updates correctly before relying on it.
