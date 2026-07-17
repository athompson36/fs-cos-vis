# Cursor Rules for FS COS VIS

## Read First

Before implementing show-control features, read:

- `docs/01-cursor-context.md`
- `docs/project-audit-and-feature-status.md`
- `docs/show-director-product-spec.md`
- `docs/show-director-architecture.md`
- `docs/show-director-implementation-roadmap.md`
- `docs/show-director-integrations.md`

## General Rules

- Inspect existing code before naming new services, stores, models, or files.
- Prefer local patterns over new architectural styles.
- Keep SwiftUI views thin.
- Put runtime behavior in stores, reducers, services, actors, or adapters.
- Keep hardware and network I/O out of reducers.
- Do not block the main actor with endpoint execution.
- Add tests for model migrations, reducers, and execution sequencing.
- Preserve existing project package formats unless a migration is explicitly added.
- Treat the Mac app as authoritative for show state.

## Show Director Rules

- Endpoint-neutral cue packages are the core abstraction.
- Cue source and cue action are separate concerns.
- DJ mode, FOH mode, remotes, MIDI, OSC, and laptop UI should all produce semantic commands into the same runtime.
- Existing visual, lighting, recording, and protocol systems should be wrapped by adapters.
- Manual override, park, blackout, and restore safe look must remain available even when automation is active.
