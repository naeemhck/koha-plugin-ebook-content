# Koha EbookContent Plugin

Protected eBook PDF metadata and controlled HTTP content delivery for Koha-linked bibliographic records.

| Item | Value |
|------|-------|
| Namespace | `Koha::Plugin::Com::Ecombranding::EbookContent` |
| Source version | `0.1.2` |
| Minimum Koha | `26.05.00.000` (metadata) |
| Tested Koha package | `koha-common 26.05.01-1` (documented live validation) |
| API namespace | `ebookcontent` |
| License | No license file is currently provided |

## Purpose

This Koha plugin maps one private, permanent `EBOOK_PDF` upload to one bibliographic record and exposes OAuth2-authenticated metadata and file-backed PDF delivery. It does **not** upload, copy, store a second PDF copy, or publish public download links.

## Architecture

- **Koha plugin role:** staff configuration page + contrib REST routes under `/api/v1/contrib/ebookcontent/`.
- **Bibliographic link:** mapping table keyed by `biblionumber` to a Koha `uploaded_file_id`.
- **Protected-content mapping:** upload must be permanent, private, category `EBOOK_PDF`, `.pdf`, nonempty, readable, and begin with `%PDF-`.
- **Server-to-server access:** Koha OAuth2 client credentials authenticate the caller; the plugin allowlists dedicated service-account patron IDs.
- **Range-enabled PDF delivery:** single `bytes=start-end` / `bytes=start-` ranges with `200` / `206` / `416` behavior; `HEAD` validates then returns headers only.
- **Digital Circulation plugin:** consumes metadata/content for protected reading after that plugin’s own loan rules.
- **Portal (`Ebook_issuing`):** proxies EbookContent through same-origin reader routes; portal never calls Koha from the browser with service credentials.

## Compatibility

- Plugin version: **0.1.2**
- Minimum Koha version (plugin metadata): **26.05.00.000**
- Documented live target: **koha-common 26.05.01-1**
- Required content assumptions: private permanent `EBOOK_PDF` uploads that are valid PDFs
- Runtime dependencies: Koha plugin framework, Mojolicious OpenAPI stack as shipped with Koha, `Koha::UploadedFiles`, `Koha::Biblios`, `Koha::Token`

## Features (confirmed from source)

- Install/upgrade creates/retains a per-plugin mappings table
- Staff configure page with CSRF-protected link/toggle/settings operations
- Service-account allowlist (`service_account_ids`)
- API enable switch (`api_enabled`)
- Configurable maximum range size (`max_range_bytes`, default 8 MiB)
- `GET …/metadata` JSON metadata for eligible mappings
- `GET` / `HEAD …/content` PDF delivery with `Accept-Ranges: bytes`
- Single-range `206` and unsatisfiable-range `416`
- Safe not-found / inactive / non-PDF error mapping
- Uninstall preserves mapping rows and never deletes Koha uploads

## Installation

1. Build the KPZ on a machine with `zip`/`unzip` (or equivalent) using `scripts/build-kpz.sh`.
2. Copy the package to the Koha host.
3. Install or upgrade through Koha's plugin tools / `install_plugins.pl` for
   `Koha::Plugin::Com::Ecombranding::EbookContent`.
4. Open the staff configuration page, set allowlisted service-account patron IDs, enable the API, and create biblio↔upload mappings.

See `docs/LIVE_VALIDATION.md` for administrator-approved live proof steps (requires real credentials supplied at runtime; never commit them).

## Configuration

| Setting | Purpose |
|---------|---------|
| `api_enabled` | Enables or disables REST delivery |
| `allowed_upload_category` | Fixed to `EBOOK_PDF` |
| `service_account_ids` | JSON array of allowlisted Koha patron IDs (service accounts) |
| `max_range_bytes` | Maximum accepted single-range length (default `8388608`) |

Do not store OAuth client secrets in this plugin; they belong to the calling service’s server configuration.

## API

Base path (Koha contrib): `/api/v1/contrib/ebookcontent`

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| `GET` | `/ebooks/{biblio_id}/metadata` | OAuth2 bearer + allowlisted service account | JSON metadata |
| `GET` | `/ebooks/{biblio_id}/content` | same | Full PDF `200` or single-range `206` |
| `HEAD` | `/ebooks/{biblio_id}/content` | same | Routed via GET; headers only, no body asset |

OpenAPI declares `x-koha-authorization` on every explicit operation. There is intentionally **no** explicit OpenAPI `head` object in 0.1.2; Mojolicious routes `HEAD` through `GET`.

Typical status codes: `200`, `206`, `401`, `403`, `404`, `409`, `415`, `416`, `500`.

## Packaging

On Debian/Linux with `zip` and `unzip`:

```bash
prove -I Koha/Plugin/Com/Ecombranding/EbookContent t/*.t
sh scripts/build-kpz.sh
```

Output: `dist/koha-plugin-ebook-content-0.1.2.kpz` (generated; not tracked in Git).

The archive root contains only `Koha/` (see `MANIFEST.md`).

## Testing

Portable / source-oriented tests (Windows or Linux development host):

```bash
prove -I Koha/Plugin/Com/Ecombranding/EbookContent t/01-range.t t/03-openapi.t t/05-controller.t t/07-compatibility-source.t
```

Full suite (requires Koha-related Perl modules such as `Mojolicious::Plugin::OpenAPI` / `JSON::Validator`, and Unix-style path expectations for some path tests):

```bash
prove -I Koha/Plugin/Com/Ecombranding/EbookContent t/*.t
```

Live Koha-host validation is documented in `docs/LIVE_VALIDATION.md` and is not claimed by the Windows source checkpoint alone.

## Security

- Protected PDFs are not exposed as public URLs by this plugin.
- OAuth client credentials and access tokens remain in the calling server (portal / Digital Circulation), never in the browser.
- Controllers require an authenticated allowlisted service-account patron.
- Mapping and upload eligibility are revalidated on every metadata/content request.
- Responses omit filesystem paths, upload roots, cookies, and tokens.
- Staff POST actions require CSRF tokens tied to `CGISESSID`.
- No real secrets belong in Git.

## Related repositories

- Digital Circulation plugin: https://github.com/naeemhck/Koha_Digital_Circulation_Plugin
- Portal: https://github.com/naeemhck/Ebook_issuing

## Development status

Verified source version **0.1.2**. Known limitations:

- Staff “Current mappings” table does not yet display upload category / private / permanent columns (validated server-side).
- Not a complete production support product by itself; depends on correct Koha OAuth service accounts and upload hygiene.
- Uninstall preserves mapping data; operators must record allowlists before uninstall.
- No license file is currently provided.

EbookContent is a **stable dependency** for Digital Circulation and the portal. Do not modify it unless a protected-content defect is proven.
