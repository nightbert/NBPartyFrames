# Changelog

## 1.0.1

### Added

- Added a setting to show or hide party-pet frames. The setting synchronizes with Blizzard's `showPartyPets` option and is included in profiles.
- Added an optional fifth party frame for the player.
- Added automatic preview switching: four frames without the player option and five frames when it is enabled.
- Added player-frame support to party layout positioning, scaling, class colors, edit-mode previews, and profiles.

### Changed

- Party health bars are recolored after Blizzard rebuilds or changes their artwork.
- Party member frames, nested health bars, compact party frames, pet frames, vehicle artwork, and pooled Blizzard frames are handled more reliably.
- Class colors are reapplied after login, reload, group roster changes, UI scale changes, and relevant unit updates.
- Party-frame scale, visibility, pet visibility, and player-frame changes that cannot be made during combat are deferred until combat ends.

### Fixed

- Fixed party pets not being displayed.
- Fixed party class colors being missing immediately after `/reload`.
- Fixed class colors disappearing when Blizzard reset a party-frame texture or atlas.
- Fixed stale color caching preventing party health bars from being repainted.
- Fixed `ADDON_ACTION_BLOCKED` caused by changing the protected party-frame scale during combat.
