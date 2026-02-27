# Internal Deployment (GHCR)

This uses private images published by the `internal-preview` workflow to GitHub Container Registry.

## One-time setup on the Droplet
1. Create a GitHub Personal Access Token with `read:packages` scope.
2. Log in to GHCR:

```sh
echo "<YOUR_GH_PAT>" | docker login ghcr.io -u <GITHUB_USERNAME> --password-stdin
```

3. Create a `plane.env` file in the same folder as the compose file. You can copy from `.env.example` and fill the values you need.

## Deploy
1. Set the release tag you want:
   - `APP_RELEASE=internal-preview` for the branch tag.
   - Or use a short SHA tag from the workflow.
2. Start services:

```sh
APP_RELEASE=internal-preview docker compose -f deployments/internal/docker-compose.ghcr.yml up -d
```

## External services variant
If you want to use DigitalOcean Managed Postgres and S3, use the external compose file and a dedicated env file:

```sh
cp deployments/internal/plane.env.example deployments/internal/plane.env
APP_RELEASE=internal-preview docker compose -f deployments/internal/docker-compose.ghcr.external.yml up -d
```

This variant removes local Postgres and MinIO. It keeps Redis and RabbitMQ local by default. If you use managed Redis, update `REDIS_URL` and remove the `plane-redis` service.

## DigitalOcean Managed Postgres setup
Before using the external compose file, do the following:
1. Add the Droplet IP (or a tag) to the DB cluster Trusted Sources so it can connect.
2. Create a dedicated database and user for Plane in the cluster.
3. Copy the connection details into `deployments/internal/plane.env`:
   - `DATABASE_URL` with `sslmode=require`
   - `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`

Then run the migrator once:

```sh
APP_RELEASE=internal-preview docker compose -f deployments/internal/docker-compose.ghcr.external.yml run --rm migrator
```

## Notes
- If you use external Postgres, Redis/Valkey, or S3 storage, remove the local services and update `plane.env`.
- For first install, run the migrator once and then stop it:

```sh
APP_RELEASE=internal-preview docker compose -f deployments/internal/docker-compose.ghcr.yml run --rm migrator
```
