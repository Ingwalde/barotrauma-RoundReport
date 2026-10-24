# Changelog

All notable changes to Round Report are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/); versions tag the game content package version in `filelist.xml`.

## [Unreleased]
### Added
- Optional performance-based round payout (`PayoutEnabled`/`PayoutPercent` in Config.lua): pays
  a host-configured cut of a voyage's net profit to the crew, weighted by round score; the rest
  stays in the campaign bank. Off by default. Campaign mode only.
  Needs native verification — the timing of this against the game's own reward payout at round
  end has not been confirmed in-game.

## [0.5.0] - 2026-10-21
### Added
- Campaign-scoped persistence: stats survive server restarts, stored per save with a backup copy for recovery.
- Configurable MVP scoring weights and penalties, synchronized to client report windows.
- Score tooltips explaining MVP calculation.

### Changed
- Rewrote Workshop listing with fuller feature, scoring and requirements sections.
- Workshop preview uses generic crew names.

## [0.4.0] - prior to 2026-10-21
### Added
- Native Barotrauma-style report window with job icons and contribution bars.
- Localized reports for all 13 game languages plus Ukrainian, with English fallback.
- Chat reports for players without the client-side LuaCs patch.
- Player statistics survive renames and authenticated reconnects while the server runs.
- `!stats`, `!mystats`, `!total`, `!rrversion` commands.

### Changed
- Separated server adapters and client view from entry points (module boundary refactor).

### Fixed
- Player stats and report delivery after player renaming.

[0.5.0]: https://github.com/Ingwalde/barotrauma-RoundReport/releases/tag/v0.5.0
[0.4.0]: https://github.com/Ingwalde/barotrauma-RoundReport/releases/tag/v0.4.0
