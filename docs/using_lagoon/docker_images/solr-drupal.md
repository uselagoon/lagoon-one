!!!warning
    **Note:** This documentation relates to developing the 1.x releases of Lagoon, built from the `master` branch.
    For documentation on the current version of Lagoon, 2.x, please visit [docs.lagoon.sh](https://docs.lagoon.sh)

# Solr-Drupal

The [Lagoon `solr-drupal` Docker image](https://github.com/amazeeio/lagoon/blob/master/images/solr-drupal/Dockerfile), is a customized[`Solr` image](./) to use within Drupal projects in Lagoon.

The initial core is `Drupal` , and it is created and configured starting from a Drupal customized and optimized configuration.

For each Solr version, there is a specific `solr-drupal:<version>` Docker image.

## Supported versions

* 5.5
* 6.6
* 7.7
