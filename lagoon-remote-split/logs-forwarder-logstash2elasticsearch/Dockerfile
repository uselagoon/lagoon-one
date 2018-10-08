FROM amazeeio/logstash

RUN bin/logstash-plugin install logstash-input-lumberjack

# Remove default shipped pipeline
RUN rm -f pipeline/logstash.conf

COPY pipeline/ pipeline/
COPY templates/ templates/
COPY certs/ certs/
COPY pipelines.yml config/pipelines.yml

# https://github.com/elastic/logstash-docker/issues/64
ENV PATH_CONFIG=null

ENV ELASTICSEARCH_URL="http://logs-db:9200" \
    LOGSDB_ADMIN_PASSWORD=admin

