# wordpress-recharge

Disposable, dockerized WordPress instance for local plugin/theme
vulnerability research — spin it up, drop in a vulnerable plugin/theme
version, test, tear down.

## Quick start

```bash
./run.sh up
```

- Starts MySQL + WordPress (latest version by default) via Docker Compose.
- Waits for the DB and WordPress to come up, then auto-runs the core
  install with:
  - **URL:** http://localhost:8080/
  - **Admin:** http://localhost:8080/wp-admin
  - **Login:** `admin` / `admin`

## Advanced options

```bash
./run.sh up -v 6.2            # pin a specific WordPress version
./run.sh up -p 8081           # use a different host port
./run.sh up -v 6.2 -p 8081    # combine both
```

`-v/--version` accepts anything the official `wordpress` Docker image
tags support (e.g. `6.4`, `6.4-php8.1`, `latest`).

## Stopping / resetting

```bash
./run.sh down       # stop containers, keep DB/site data
./run.sh destroy    # stop containers AND wipe all volumes (fresh slate)
```

## Downloading a plugin to test

Use `plugins-downloader.py` to grab a plugin zip from
downloads.wordpress.org — latest release or a pinned version (useful
for reproducing a specific CVE):

```bash
# latest version
./plugins-downloader.py --url https://wordpress.org/plugins/wedevs-project-manager/

# exact version (downloads.wordpress.org/plugin/wedevs-project-manager.4.1.2.zip)
./plugins-downloader.py --url https://wordpress.org/plugins/wedevs-project-manager/ -v 4.1.2

# custom output directory
./plugins-downloader.py --url https://wordpress.org/plugins/wedevs-project-manager/ -v 4.1.2 -o ./plugins
```

Then install it into the running instance, e.g.:

```bash
docker compose run --rm -v "$(pwd)/plugins:/mnt/plugins" wpcli \
  wp plugin install /mnt/plugins/wedevs-project-manager.4.1.2.zip --activate
```

## Notes

- This is meant for **local, authorized** security testing only —
  don't expose port 8080 beyond your own machine/lab network.
- Data persists in Docker volumes across `up`/`down`; use `destroy` to
  fully reset between engagements.
