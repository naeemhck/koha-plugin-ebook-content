# Teammate Handoff — Koha EbookContent Plugin

Professional continuation guide for cloning this repository on another computer.

## Repository identity

| Item | Value |
|------|-------|
| GitHub repository | https://github.com/naeemhck/koha-plugin-ebook-content |
| Default branch | `main` |
| Namespace | `Koha::Plugin::Com::Ecombranding::EbookContent` |
| Version | `0.1.2` |
| Minimum Koha (metadata) | `26.05.00.000` |
| Documented Koha package | `koha-common 26.05.01-1` |

## Folder structure

| Path | Role |
|------|------|
| `Koha/Plugin/Com/Ecombranding/EbookContent.pm` | Plugin lifecycle, mapping table, validation, staff configure |
| `Koha/Plugin/Com/Ecombranding/EbookContent/Controller.pm` | REST metadata/content controllers |
| `Koha/Plugin/Com/Ecombranding/EbookContent/Path.pm` | Safe path resolution |
| `Koha/Plugin/Com/Ecombranding/EbookContent/Range.pm` | HTTP byte-range parsing |
| `Koha/Plugin/Com/Ecombranding/EbookContent/openapi.json` | Contrib route definitions |
| `Koha/Plugin/Com/Ecombranding/EbookContent/configure.tt` | Staff configuration template |
| `t/` | Portable and framework-oriented tests |
| `scripts/build-kpz.sh` | KPZ packaging |
| `scripts/create-synthetic-pdf.pl` | Synthetic PDF helper for labs |
| `docs/` | Live validation and checkpoint docs |
| `dist/` | Generated KPZ output (gitignored) |

## Environment

Required for packaging/tests (names only):

- Perl 5 with `prove`
- For full route/OpenAPI tests: Koha-compatible Mojolicious OpenAPI stack
- For packaging: `zip` + `unzip` (or `7z`) on Unix
- On Koha host: working Koha instance, plugin install tools, OAuth client for service accounts

Never commit `.env`, client secrets, tokens, or production PDFs.

## Responsibilities

### EbookContent owns

- biblio ↔ protected `EBOOK_PDF` upload mapping
- metadata JSON for eligible mappings
- content streaming via `Mojo::Asset::File`
- `GET` / `HEAD` / single-range handling (`200` / `206` / `416`)
- service-account allowlist checks after Koha OAuth authentication
- staff mapping/settings UI with CSRF protection

### EbookContent does not own

- portal patron login sessions
- digital request approval workflows
- authoritative digital-loan lifecycle (issue/return/renew/revoke/expiry)
- portal reader-entitlement decisions
- native Koha circulation (`issues` table)

## Relationships

| System | Repository | Connection |
|--------|------------|------------|
| Digital Circulation | https://github.com/naeemhck/Koha_Digital_Circulation_Plugin | Uses protected content after its own loan rules |
| Portal | https://github.com/naeemhck/Ebook_issuing | Proxies EbookContent; browser never holds service OAuth |

Shared identity key: positive Koha **biblio ID**. Portal and Digital Circulation correlate loans/requests to the same biblio; EbookContent serves that biblio’s mapped PDF only to allowlisted service accounts.

Credential boundary: OAuth client ID/secret and access tokens stay on the calling server.

## Setup on another computer

```powershell
git clone https://github.com/naeemhck/koha-plugin-ebook-content.git
Set-Location koha-plugin-ebook-content
git checkout main
git pull
git rev-parse --short HEAD
```

Portable tests:

```bash
prove -I Koha/Plugin/Com/Ecombranding/EbookContent t/01-range.t t/03-openapi.t t/05-controller.t t/07-compatibility-source.t
```

Package (Debian/Linux):

```bash
sh scripts/build-kpz.sh
```

Install the resulting `dist/koha-plugin-ebook-content-0.1.2.kpz` on the Koha host using the site’s plugin install process.

## Validation baseline (this checkpoint)

Executed on the Windows development host during source publication:

- `t/01-range.t`, `t/03-openapi.t`, `t/05-controller.t`, `t/07-compatibility-source.t`: **PASS** (69 tests)
- Full `t/*.t` on Windows without Koha modules: environment failures only
  - `t/02-path.t`: Windows path separator string comparison
  - `t/04-route-loader.t` / `t/06-merged-openapi.t`: missing `Mojolicious::Plugin::OpenAPI` / `JSON::Validator` outside Koha
- Path/Range modules: `perl -c` syntax OK
- Existing generated package inspected (untracked): `dist/koha-plugin-ebook-content-0.1.2.kpz`, 9046 bytes, 11 archive members

Koha-host live install/proof was **not** re-executed in this GitHub upload unit.

## Safe development rules

- No real patron PDFs or sensitive material in Git
- No credentials in source
- No manual production table edits outside supported staff UI / reviewed migrations
- Preserve range semantics and `206` / `416` behavior
- Preserve eligibility checks and service-account authorization
- Preserve HEAD-through-GET OpenAPI compatibility (no incompatible explicit `head` object)

## Known limitations

- Mapping table UI omits some upload status columns
- Full prove suite expects Unix/Koha Perl environment
- Uninstall preserves mappings; record allowlists first
- No license file provided

## Next safe task

Treat EbookContent as a **stable dependency**. Do not modify it unless the portal or Digital Circulation work proves a specific protected-content defect. Prefer continuing Digital Circulation / portal units instead.
