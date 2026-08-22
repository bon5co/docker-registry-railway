# Docker Registry (CNCF distribution) packaged for Railway.
#
# Upstream's image is correct but ships wide open: with no REGISTRY_AUTH set,
# anyone who finds the URL can push, pull and overwrite every tag. On a public
# Railway domain that is an anonymous write endpoint on the internet. There is
# no way to close it from environment variables alone, because htpasswd auth
# needs a FILE and the file has to be built from the deployer's credentials at
# boot. That is the whole reason this wrapper exists.
#
# Pinned by digest, not by tag: registry:3.0.0 today and registry:3.0.0 in six
# months, so a redeploy can never swap the storage driver under a live volume.
FROM registry@sha256:6c5666b861f3505b116bb9aa9b25175e71210414bd010d92035ff64018f9457e

# htpasswd, for the bcrypt hash distribution requires. Adds ~1 MB.
RUN apk add --no-cache apache2-utils

# Baked, NOT published as template variables. templateGenerate drops a variable
# whose default is a literal, so anything shipped that way would publish as a
# blank REQUIRED field on the deploy form. Only REGISTRY_PASSWORD is a variable,
# and it is a ${{secret(n)}} expression, whose default does survive.
ENV REGISTRY_USERNAME=admin \
    REGISTRY_HTTP_ADDR=:8080 \
    REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/var/lib/registry \
    REGISTRY_STORAGE_DELETE_ENABLED=true \
    REGISTRY_HTTP_HEADERS_X-Content-Type-Options="[nosniff]" \
    REGISTRY_LOG_LEVEL=info \
    OTEL_TRACES_EXPORTER=none

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
