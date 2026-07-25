# Project Checkpoint — Koha EbookContent Plugin

| Field | Value |
|-------|-------|
| Date | 2026-07-25 |
| Namespace | `Koha::Plugin::Com::Ecombranding::EbookContent` |
| Source version | `0.1.2` |
| Discovered project root | `D:\KohaPluginWorkspace\koha-plugin-ebook-content` |
| Workspace base (not the repo root) | `D:\KohaPluginWorkspace` |

## Source inventory summary

Tracked project content under the narrow plugin root:

- Perl modules: `EbookContent.pm`, `Controller.pm`, `Path.pm`, `Range.pm`
- OpenAPI: `openapi.json`
- Staff template: `configure.tt`
- Tests: `t/01` … `t/07`
- Scripts: `build-kpz.sh`, `create-synthetic-pdf.pl`
- Docs: README, SECURITY, CHANGELOG, MANIFEST, LIVE_VALIDATION, teammate handoff, this checkpoint

Excluded from Git: `dist/*.kpz`, workspace sibling reports under `D:\KohaPluginWorkspace\*.md`, workspace `validation/` and root `dist/`.

## API summary

- Namespace: `ebookcontent`
- `GET /ebooks/{biblio_id}/metadata`
- `GET|HEAD /ebooks/{biblio_id}/content` (HEAD via GET route)
- Auth: Koha OAuth bearer + plugin service-account allowlist
- Ranges: single byte ranges; `206` / `416`

## Configuration summary

`api_enabled`, fixed `EBOOK_PDF` category, `service_account_ids`, `max_range_bytes`.

## Test results

| Suite | Result |
|-------|--------|
| Portable prove (`01`, `03`, `05`, `07`) | PASS (69 tests) |
| Full prove on Windows without Koha stack | Environment failures (`02` path separators; `04`/`06` missing OpenAPI modules) |
| Koha-host live validation this unit | Not re-run |

## Packaging result

Existing untracked package inspected:

| Property | Value |
|----------|-------|
| Filename | `dist/koha-plugin-ebook-content-0.1.2.kpz` |
| Size | 9046 bytes |
| Members | 11 |
| SHA-256 | `f60b7b022251a14185f2493d5a32bba23b95d215523344982e6199d5a8e8f659` |

Not committed. A future GitHub release `v0.1.2` could attach a re-validated KPZ after Debian `scripts/build-kpz.sh` proof; this checkpoint does **not** create that release.

## Relationship to portal and Digital Circulation

- Portal checkpoint (read-only): branch `feature/koha-backed-request-orchestration`, commit `bbcf522`
- Digital Circulation: branch `feature/phase2c-loan-issuance-foundation`, commit `feba778`
- EbookContent remains the protected PDF metadata/content dependency; Phase 4A portal entitlement does not change this plugin

## GitHub upload status

Filled after push in the publication unit (see final report).

## Known limitations

- Staff mapping UI status-column gap
- Windows portable host cannot run full Koha OpenAPI prove suite
- No license file
- Not modified unless a proven protected-content defect appears
