ARG IMAGE_REPO
FROM ${IMAGE_REPO:-amazeeio}/php:7.1-cli-drupal

COPY composer.json composer.lock /app/
COPY scripts /app/scripts
RUN composer install --no-dev
RUN node --version
RUN yarn --version
COPY . /app

ENV WEBROOT=web
