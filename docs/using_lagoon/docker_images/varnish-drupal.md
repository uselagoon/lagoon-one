!!!warning
    **Note:** This documentation relates to developing the 1.x releases of Lagoon, built from the `master` branch.
    For documentation on the current version of Lagoon, 2.x, please visit [docs.lagoon.sh](https://docs.lagoon.sh)

# Varnish-Drupal

The [Lagoon `varnish-drupal` Docker image](https://github.com/amazeeio/lagoon/blob/master/images/varnish-drupal/Dockerfile). It is a customized [`varnish` image](./) to use within Drupal projects in Lagoon.

It differs from `varnish` only for `default.vcl` file, optimized for Drupal on Lagoon.

