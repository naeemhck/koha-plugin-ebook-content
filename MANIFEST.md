# Package manifest

The `.kpz` ZIP root contains only `Koha/`:

- Main plugin module and lifecycle logic
- REST controller
- Path and range helpers
- OpenAPI route definition
- Staff configuration template

Development-only `t/`, `scripts/`, `docs/`, and Markdown files are intentionally excluded from the installable archive by `scripts/build-kpz.sh`.
