# Architecture

The two `Lua/Autorun` scripts are composition roots. They load dependencies, create
runtime objects and install adapters. Importing an adapter alone does not register
hooks, open windows or send messages.

## Boundaries

| Module | Responsibility |
| --- | --- |
| `Stats` | Round/total bookkeeping; no game API |
| `Report` | Scores, awards, rows and report text; no game API |
| `Strings` | Translation catalogs and English fallback; no game API |
| `Language` | Game-language lookup and explicit locale overrides |
| `Net` | Wire encoding/decoding; no hook registration or message delivery |
| `Server/Players` | Account/session identity, names and character resolution |
| `Server/Tracking` | Translate game karma/death events into stat deltas |
| `Server/Delivery` | Chat commands, GUI/chat delivery and round-end lifecycle |
| `Client/Controller` | Receive packets, announce GUI capability and schedule drawing |
| `Client/Window` | Build/render native widgets from decoded report data |

Dependencies are passed to constructors/installers explicitly. Game adapters use
LuaCs globals at their boundary; domain modules remain executable without the game.
The view never parses packets, and tracking never sends reports.

## State and reloads

Only the server composition root owns the `RoundReport` global. Its `stats` and
`players` fields survive `reloadlua`; module closures are recreated around the same
state. Hook/message identifiers remain unchanged so LuaCs replaces registrations.
Disconnect removes session capability state, while authenticated account records
retain accumulated statistics. Account identifiers never enter report packets.

The client window owns its current round/total snapshot and widgets. Its controller
passes complete decoded snapshots to `show` and calls `update` during GUI updates.
Locale is resolved once per Lua load to keep static and dynamic text consistent.

## Extending the mod

- New tracked activity: add the field to `Stats.FIELDS`, then map a game callback in
  `Server/Tracking`. Changing field order changes the wire format; update both ends.
- Scoring rules: change `Report`, its tests and the translated score explanations.
- Presentation: change `Client/Window`; transport and identity should not change.
- Languages: add a complete catalog to `Strings` and an identifier to `Language`.
  Missing keys and unknown languages fall back to English.
- Persistence: introduce an explicit storage adapter; keep disk access out of
  `Stats` and `Report` and avoid persisting GUI capability/session state.

All runtime Lua files must appear in `filelist.xml`. Run the Python tests with
`lupa` installed. Identity/reload, client interaction and localization regressions
exercise the entry points; architecture tests check module loading and packaging.
Native gameplay verification is separate from mocked API tests.
