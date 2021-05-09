A set of scripts to help with [early access](https://codecrafters.io/early-access) trials.

## Secrets

- `CODECRAFTERS_BOT_GITHUB_TOKEN`: a token with read-access to codecrafters-io/alpha-landing.

To preview role changes: 

``` sh
make sync_roles
```

To apply role changes: 

``` sh
REALLY_SYNC=true make sync_roles
```
