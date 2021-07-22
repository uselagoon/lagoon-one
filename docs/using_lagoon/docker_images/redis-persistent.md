!!!warning
    **Note:** This documentation relates to developing the 1.x releases of Lagoon, built from the `master` branch.
    For documentation on the current version of Lagoon, 2.x, please visit [docs.lagoon.sh](https://docs.lagoon.sh)

# Redis-persistent

The [Lagoon `redis-persistent` Docker image](https://github.com/amazeeio/lagoon/blob/master/images/redis-persistent/Dockerfile). Based on the [Lagoon `redis` image](./), it is intended for use if the Redis service must be in `persistent` mode \(ie. with a persistent volume where transactions will be saved\).

It differs from `redis` only for `FLAVOR` environment variable.

