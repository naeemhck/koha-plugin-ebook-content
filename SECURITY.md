# Security design

- Koha OAuth2 client credentials provide authentication; the plugin implements no token system.
- Every OpenAPI operation includes `x-koha-authorization`; contrib routes without it would be anonymous in this Koha version.
- A plugin-owned allowlist restricts calls to dedicated authenticated service-account patron IDs.
- Uploads must be permanent, private, category `EBOOK_PDF`, `.pdf`, nonempty, readable, and begin `%PDF-` on every request.
- The upload is found with `Koha::UploadedFiles->find`. The candidate and configured root are resolved with `abs_path`; `abs2rel` rejects traversal and symlink escape.
- Responses never include `dir`, `hashvalue`, upload root, real path, public URL, credentials, cookies, or tokens.
- SHA-256 uses streaming reads. PDF delivery uses `Mojo::Asset::File`; no full-file buffer or second persistent PDF is created.
- Range parsing accepts only `bytes=start-end` and `bytes=start-`. Suffix and multiple ranges are rejected with 416. End-past-EOF, reversed, malformed, and oversized ranges are rejected.
- `HEAD` performs all validation but attaches no body asset.
- Uninstall and mapping deactivation never delete the Koha upload.

Report vulnerabilities privately to the plugin maintainer. Do not include tokens, credentials, paths, or uploaded content in reports.
