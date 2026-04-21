# Fixture Source Provenance

This project's curated fixture import workflow is centered on the Open Fixture Library (OFL) data model.

## Primary source

- Open Fixture Library fixture definitions and register:
  - https://github.com/OpenLightingProject/open-fixture-library
  - `fixtures/register.json`
  - `fixtures/<manufacturer>/<fixture>.json`

## Open-source ecosystems reviewed for fixture-list prioritization

- QLC+ (fixture ecosystem and usage patterns)
- OLA ecosystem references and community fixture usage
- OFL project community/manufacturer coverage

## Policy in this project

- We import and cache OFL-compatible fixture data and retain OFL identifiers (`oflFixtureKey`, `oflModeName`) in profiles.
- Curated presets (top manufacturers and fog/haze-friendly entries) are used as a practical starting point for operators.
- We do not blindly copy incompatible fixture formats from other projects; we use those ecosystems to prioritize discovery and curation.

## Fog/Haze emphasis

Curated manufacturer seeds include major fog/haze vendors and effect-fixture manufacturers. Entries are additionally tagged with a fog/haze heuristic (name/category matching) for quick discovery.

## Starter rig (Chauvet DJ, American DJ, Elation)

Curated fallback rows in `OFLFixtureImportService.curatedFallbackFixtures` ensure these fixtures appear in the merged catalog even when the OFL register sync omits them. Import loads **bundle-first** JSON from `FSDMXVision/FSDMXVision/Resources/Fixtures/<manufacturer>/<fixture>.json`, then cache, then the OFL GitHub raw URL.

| Display name | Catalog key (`manufacturer/fixture`) | Definition source |
| --- | --- | --- |
| Hurricane Haze 1DX | `chauvet-dj/hurricane-haze-1dx` | OFL (remote) when reachable; same path in bundle optional |
| SlimPAR Pro RGBA | `chauvet-dj/slimpar-pro-rgba` | OFL (remote) |
| SlimPAR T12 USB | `chauvet-dj/slimpar-t12-usb` | OFL (remote) |
| Mega Bar 50RGB | `american-dj/mega-bar-50rgb` | OFL (remote) |
| Inno Pocket Fusion | `american-dj/inno-pocket-fusion` | OFL (remote) |
| Inno Pocket Beam Q4 | `american-dj/inno-pocket-beam-q4` | OFL (remote) |
| DP-415 | `elation/dp-415` | App-bundled OFL-shaped JSON + Elation manual |
| DP-415R | `elation/dp-415r` | App-bundled OFL-shaped JSON + Elation manual |
| Scorpion Dual | `chauvet-dj/scorpion-dual` | App-bundled (verify / upstream OFL PR welcome) |
| Storm FX RGB | `chauvet-dj/storm-fx-rgb` | App-bundled (verify) |
| Circus 2.0 IRC | `chauvet-dj/circus-2-0-irc` | App-bundled (verify) |
| SlimPAR 64 RGBA | `chauvet-dj/slimpar-64-rgba` | App-bundled (verify) |
| SlimPAR 56 ILS | `chauvet-dj/slimpar-56-ils` | App-bundled (verify) |
| Sparkle | `american-dj/sparkle` | App-bundled (verify) |
| P64 LED | `american-dj/p64-led` | App-bundled (verify) |
| Inno Pocket Scan | `american-dj/innopocket-scan` | App-bundled (verify) |
| Kaptivator 3D RGB Laser | `blizzard/kaptivator-3d-rgb` | App-bundled (not in OFL upstream as of check; verify DMX chart in manual) |

Bundled definitions are operator convenience only; channel counts and modes should be checked against the manufacturer manual before show-critical use.

### Product URLs and thumbnails

- Canonical **product and manual URLs** for this rig are listed in [`docs/fixtures/starter-rig-metadata.json`](fixtures/starter-rig-metadata.json).
- **Thumbnails**: do not automate unchecked web scraping of manufacturer or retailer sites. Prefer manual, licensed assets in-repo, or link out only.

### Hurricane Haze 1DX + DP-415R

This is a **system** (hazer + dimmer), not a single OFL fixture. Patch the hazer and the dimmer as separate instances. Use **per-instance channel label overrides** and **rig notes** on the patch row (Lighting workspace) to document which dimmer output drives pump, haze level, or mains switching.
