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
