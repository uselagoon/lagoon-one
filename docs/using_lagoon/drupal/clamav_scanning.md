!!!warning
    **Note:** This documentation relates to developing the 1.x releases of Lagoon, built from the `master` branch.
    For documentation on the current version of Lagoon, 2.x, please visit [docs.lagoon.sh](https://docs.lagoon.sh)

# ClamAV Scanning
There is now a ClamAV scanner daemon running within each Lagoon cluster. This daemon can be used with Drupal to scan files dynamically as they are uploaded to ensure they are free from viruses.

## Drupal Module Installation
In order to use this functionality, the [ClamAV Drupal module](https://www.drupal.org/project/clamav) must be installed and enabled.

## Drupal Module Configuration
Configuring this functionality is quite simple. See the screenshot below for a working example configuration:

![ClamAV Module Configuration Example](clamav_config.png)