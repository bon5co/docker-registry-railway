# docker-registry-railway

The CNCF [distribution](https://github.com/distribution/distribution) registry
(`registry:3.0.0`, pinned by digest) packaged for Railway, with the one thing
the stock image cannot do for itself: **basic authentication**.

Upstream reads its whole configuration from environment variables except for
credentials — `REGISTRY_AUTH_HTPASSWD_PATH` is a file path, and distribution
accepts only bcrypt hashes in it. So a registry deployed from environment
variables alone is always anonymous, and on a public domain that means anyone
who finds the URL can push, pull and overwrite every tag in it.

This entrypoint builds the htpasswd file from `REGISTRY_USERNAME` /
`REGISTRY_PASSWORD` at boot, then execs the stock entrypoint unchanged.

Also set here, and all missing from the stock deployment:

- `REGISTRY_STORAGE_DELETE_ENABLED=true` — without it the delete API returns
  405 and there is no way to reclaim space; the volume only ever grows.
- `OTEL_TRACES_EXPORTER=none` — the 3.x default config posts traces to
  `localhost:4318` and logs a connection-refused error for every batch.
- `REGISTRY_LOG_LEVEL=info` — the shipped config runs at `debug` in
  `development` mode.
- A boot-time write test against the storage root, so an unwritable volume
  fails the deploy instead of serving a healthy registry that drops every push.

`GET /` answers 200 without credentials while `/v2/` is gated, so `/` is the
healthcheck path.

## Reclaiming space

Deleting a manifest through the API unlinks it; the blobs are freed by the
garbage collector:

```
registry garbage-collect --delete-untagged /etc/distribution/config.yml
```
