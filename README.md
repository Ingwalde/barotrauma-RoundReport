# Round Report

Barotrauma multiplayer mod (Lua). Tracks per-player stats each round and announces an MVP when the round ends.

![Expedition debrief preview](docs/roundreport-interface-preview.png)

*Illustrative render of the Lua widget layout with demonstration data and native game styles,
not an in-game screenshot. Live LuaCs rendering still needs verification.*

## What it tracks

Repairs, welding, healing (including CPR), fire extinguishing, damage dealt, kills, deaths, friendly fire and reactor meltdowns. The MVP score is the player's share of each team total, minus penalties for deaths and friendly fire. A reactor meltdown removes MVP eligibility.

## Features

- End-of-round report in chat for everyone.
- Optional report window (tabs: this round / totals) for players who have the client-side LuaCs patch. Players without it get chat lines.
- Expedition debrief layout: MVP card, team totals, job icons, crew contributions,
  score bars relative to the MVP, and separate scrollable commendations and incidents.
  Negative scores remain visible. Your row is highlighted in green; category leaders
  have green values. Long names and report lines have full-text tooltips.
- Hover a score or the score column heading for the MVP formula, thresholds,
  penalties and tie-breaking rules in the selected language.
- Chat commands: `!stats` (this round, all players), `!mystats` (only you),
  `!total` (saved totals for this campaign), and `!rrversion` (diagnostics).
- Language follows the local game settings by default. All 13 languages shipped with
  Barotrauma 1.13.4.0 are included, plus Ukrainian: English, German, French, Polish,
  Russian, Brazilian Portuguese, Castilian and Latin American Spanish, Turkish,
  Japanese, Korean, Simplified and Traditional Chinese. New or unknown languages
  and missing translation keys fall back to English.
  Each player's window uses their own language; server-generated chat uses the server's
  language. Reload Lua after changing the game language. Set `Language` to a locale code
  such as `uk`, `de` or `zh-CN`
  in `Lua/RoundReport/Config.lua` to override. Bots can also be included or excluded there.
- Player stats survive renames and authenticated reconnects during the server's lifetime.
  Reconnecting without an account ID starts a new player record.
- Version 0.5 stores totals separately beside each campaign save and restores them
  after server restarts. Current-round data starts fresh. Writes are batched and keep
  a backup copy; corrupt primary data falls back to the backup.
- MVP category weights, death/friendly-fire penalties and reactor disqualification
  are configurable on the server. The server sends those rules to client windows.

## Requirements

- Barotrauma 1.13.4.0
- [Lua For Barotrauma](https://github.com/evilfactory/LuaCsForBarotrauma) enabled on the host
- Multiplayer only. Stats come from server-side karma hooks, so there is nothing to
  report in single player. Campaign totals persist; current-round data resets when
  the server restarts.

## Install

For the clean upload package and prepared Steam description, see
[Workshop release preparation](docs/workshop-release.md).

Copy this folder into `<Steam>/steamapps/common/Barotrauma/LocalMods/RoundReport`. Enable it and Lua For Barotrauma in Settings -> Mods, then host a server. Use `reloadlua` in the server console to reload scripts.

When updating from the original name-based tracking, restart the server once to clear
legacy in-memory records. Subsequent `reloadlua` calls preserve the new player identities,
stats, and connected clients' window support.

## Status

Version 0.5.0. The previous 0.4 build was manually verified through a complete multiplayer round on
Barotrauma 1.13.4.0 with LuaCs 1.0.116. Network delivery, gameplay stat tracking,
MVP rendering, tabs, layout bounds, and close/reopen worked. Version 0.5 adds
campaign persistence and configurable scoring and requires native verification.
The client tests cover period switching, empty reports,
negative scores, localization, close/reopen behavior, and section sizes at 720p–1440p.

## Tests

See [Architecture](docs/architecture.md) for module boundaries, reload behavior and extension points.

```
pip install lupa
python tests/test_roundreport.py .
python tests/test_roundreport_client.py .
python tests/test_player_identity.py
python tests/test_localization.py
python tests/test_architecture.py
python tests/test_v05.py
```
