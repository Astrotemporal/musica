# Plan: auto-generated musica.env documentation

## Goal

Generate a `docs/musica-env.md` reference from `rpi-image/config/musica.env.template`
so the field descriptions stay in one place and the docs are always in sync.

## Source of truth

`rpi-image/config/musica.env.template` — already structured with:
- `# description` comments above each field
- blank-line separated sections
- `FIELD=default_value` lines

## Proposed output

`docs/musica-env.md` — committed generated markdown (viewable on GitHub without
running anything), containing a table or per-section breakdown:

| Variable | Default | Description |
|---|---|---|
| ZEROTIER_NETWORK_ID | | Your 16-character ZeroTier network ID |
| LASTFM_ENABLED | false | Last.fm scrobbling (optional) |
| ... | | |

## Files to add

- `scripts/gen-env-docs.sh` — parses the template into markdown
- `docs/musica-env.md` — committed generated output
- `Makefile` target `docs` — runs the script and overwrites `docs/musica-env.md`

## Script approach

Parse the template line by line:
- Comment lines (`# ...`) above a field become the description
- `FIELD=value` lines supply the variable name and default
- Blank lines delimit sections (can become markdown `###` headings)
