ARG UPSTREAM_REPO
ARG UPSTREAM_TAG
FROM ${UPSTREAM_REPO:-testlagoon}/solr-5.5-drupal:${UPSTREAM_TAG:-latest}
