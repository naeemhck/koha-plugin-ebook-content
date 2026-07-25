# Live installation and validation

Run only after administrator approval. Replace placeholders locally; never paste resulting secrets or tokens into logs or chat.

## 1. Install the reviewed package

Package expected on Windows:

```text
D:\KohaPluginWorkspace\koha-plugin-ebook-content\dist\koha-plugin-ebook-content-0.1.2.kpz
```

Because this instance has `plugins_restricted=1`, use the administrator-approved manual installation workflow. One option is to copy the package to the VM, inspect it, extract it into the configured plugin directory, and run Koha's supported initializer. The administrator must identify the configured plugin directory without disclosing it:

```powershell
scp -o BatchMode=yes -o IdentitiesOnly=yes `
  -i "$env:USERPROFILE\.ssh\koha_codex" `
  "D:\KohaPluginWorkspace\koha-plugin-ebook-content\dist\koha-plugin-ebook-content-0.1.2.kpz" `
  debian@192.168.133.129:/home/debian/koha-plugin-ebook-content/dist/
```

On Debian, after reviewing `unzip -l` output:

```bash
unzip -t /home/debian/koha-plugin-ebook-content/dist/koha-plugin-ebook-content-0.1.2.kpz
unzip -l /home/debian/koha-plugin-ebook-content/dist/koha-plugin-ebook-content-0.1.2.kpz
```

Installation changes plugin files and creates the mapping table, so stop here until the administrator approves the exact extraction and `install_plugins.pl` commands for the configured plugin directory.

## 2. Configure upload category

In Koha staff:

1. Administration > Authorized values.
2. Open category `UPLOAD`.
3. Create `EBOOK_PDF` if it does not exist.
4. Do not change unrelated values.

## 3. Create a synthetic private upload

Generate project-owned test data outside Koha, then upload it through Koha:

```bash
perl scripts/create-synthetic-pdf.pl /tmp/koha-ebook-proof.pdf
```

In Tools > Upload:

- Category: `EBOOK_PDF`
- Public download: unchecked
- Record the displayed Upload ID

Delete the local `/tmp/koha-ebook-proof.pdf` after Koha upload verification so Koha retains the only permanent copy.

## 4. Map and authorize

1. Assign only `plugins.admin` or `plugins.configure` to the staff librarian managing mappings.
2. Open the plugin configuration page.
3. Enter the dedicated service account's Koha patron ID in the allowlist. Do not enter its OAuth client ID or secret.
4. Leave API enabled.
5. Enter `$BIBLIO_ID` and `$UPLOAD_ID`.
6. Select **VERIFY AND LINK FILE**.
7. Confirm the page shows only safe filename, size, SHA-256, IDs, status, and time—never a path or URL.

## 5. Obtain an OAuth2 token

Use environment variables or a protected local secret store. Avoid shell tracing and command history containing secrets.

```bash
export KOHA_BASE_URL='https://KOHA-HOST'
export CLIENT_ID='placeholder'
read -rs CLIENT_SECRET
export CLIENT_SECRET

TOKEN=$(curl -fsS -u "$CLIENT_ID:$CLIENT_SECRET" \
  -d 'grant_type=client_credentials' \
  "$KOHA_BASE_URL/api/v1/oauth/token" | jq -r .access_token)
test -n "$TOKEN" && test "$TOKEN" != null
```

Do not print `$TOKEN`.

## 6. Metadata

```bash
curl -i -H "Authorization: Bearer $TOKEN" \
  "$KOHA_BASE_URL/api/v1/contrib/ebookcontent/ebooks/$BIBLIO_ID/metadata"
```

Expected: 200 safe JSON; no `dir`, path, hashvalue, token, cookie, or public URL.

## 7. Full GET

```bash
curl -sS -D /tmp/ebook.headers -o /tmp/ebook.response.pdf \
  -H "Authorization: Bearer $TOKEN" \
  "$KOHA_BASE_URL/api/v1/contrib/ebookcontent/ebooks/$BIBLIO_ID/content"
sed -n '1,30p' /tmp/ebook.headers
head -c 5 /tmp/ebook.response.pdf
```

Expected: 200, `application/pdf`, inline disposition, `%PDF-`, security headers, and no path. This response file is temporary validation data and must be removed afterward.

## 8. HEAD

```bash
curl -I -H "Authorization: Bearer $TOKEN" \
  "$KOHA_BASE_URL/api/v1/contrib/ebookcontent/ebooks/$BIBLIO_ID/content"
```

Expected: 200, correct `Content-Length`, `Accept-Ranges: bytes`, security headers, and no body.

## 9. Valid range

```bash
curl -sS -D /tmp/range.headers -o /tmp/range.bin \
  -H "Authorization: Bearer $TOKEN" -H 'Range: bytes=0-1023' \
  "$KOHA_BASE_URL/api/v1/contrib/ebookcontent/ebooks/$BIBLIO_ID/content"
wc -c /tmp/range.bin
sed -n '1,30p' /tmp/range.headers
```

Expected: 206, 1024 bytes, `Content-Range: bytes 0-1023/TOTAL`, and `Content-Length: 1024`.

## 10. Invalid and unsupported ranges

```bash
curl -i -H "Authorization: Bearer $TOKEN" -H 'Range: bytes=999999999-' \
  "$KOHA_BASE_URL/api/v1/contrib/ebookcontent/ebooks/$BIBLIO_ID/content"
curl -i -H "Authorization: Bearer $TOKEN" -H 'Range: bytes=-1024' \
  "$KOHA_BASE_URL/api/v1/contrib/ebookcontent/ebooks/$BIBLIO_ID/content"
curl -i -H "Authorization: Bearer $TOKEN" -H 'Range: bytes=0-1,3-4' \
  "$KOHA_BASE_URL/api/v1/contrib/ebookcontent/ebooks/$BIBLIO_ID/content"
```

Expected: 416 and `Content-Range: bytes */TOTAL` for each.

## 11. Authentication and authorization denials

```bash
curl -i "$KOHA_BASE_URL/api/v1/contrib/ebookcontent/ebooks/$BIBLIO_ID/metadata"
curl -i -H 'Authorization: Bearer invalid' \
  "$KOHA_BASE_URL/api/v1/contrib/ebookcontent/ebooks/$BIBLIO_ID/metadata"
curl -i -H "Authorization: Bearer $UNAUTHORIZED_TOKEN" \
  "$KOHA_BASE_URL/api/v1/contrib/ebookcontent/ebooks/$BIBLIO_ID/metadata"
curl -i -H "Authorization: Bearer $TOKEN" \
  "$KOHA_BASE_URL/api/v1/contrib/ebookcontent/ebooks/$WRONG_BIBLIO_ID/content"
```

Expected: missing/invalid authentication 401, authenticated non-allowlisted account 403, and wrong biblio 404. No PDF bytes or private metadata should be returned.

## 12. Policy rejection matrix

Using synthetic test uploads only, attempt mapping for public, temporary, wrong-category, non-PDF-extension, invalid-signature, empty, missing, and symlink-escape cases. Each must fail without exposing a path. Deactivate the valid mapping and verify metadata/content are rejected; reactivate only after validation succeeds.

## 13. No-public-URL and no-second-copy checks

- Confirm metadata and all error bodies contain no URL, `dir`, upload root, or hashvalue.
- Confirm the plugin table contains metadata only and no blob/base64/path columns.
- Confirm no plugin cache or copied PDF appears under the plugin directory.
- Monitor process memory during full and range requests; range responses must use file-backed assets and remain bounded.
- Remove `/tmp/ebook.response.pdf`, `/tmp/range.bin`, headers, and the original synthetic generator output after validation.

Live installation and these results are not claimed by the package build.
