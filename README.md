# Docker images for GeoNode services
**This is a WIP. Further details will be provided in this README once the repo has been stabilized.**

This repository collects the configurations for the Docker images used by GeoNode and GeoNode project Docker compose files.
It replaces the configurations defined in the following locations:
- https://github.com/GeoNode/geonode-project/tree/master/docker
- https://github.com/GeoNode/geonode/tree/master/scripts/docker (will be removed except the [GeoNode base image](https://github.com/GeoNode/geonode/tree/master/scripts/docker/base/ubuntu))
- https://github.com/GeoNode/geoserver-docker (will be archived and deprecated)
- https://github.com/GeoNode/data-docker (will be archived and deprecated)
- https://github.com/GeoNode/nginx-docker (will be archived and deprecated)
- https://github.com/GeoNode/postgis-docker (will be archived and deprecated)

The [configurations](https://github.com/GeoNode/geonode-project/tree/master/docker) in the GeoNode Project repository will by default inherit from these base images without further configurations. These configurations can be customized inside projects for any specific need.

## Builds and publishing to GHCR

The images (`nginx`, `geoserver`, `postgis`, `letsencrypt`) are built and published by
`.github/workflows/docker-image.yml` to `ghcr.io/nds-cprm/opengeosgb-<image>` (e.g. `ghcr.io/nds-cprm/opengeosgb-nginx:1.31.10`), for amd64 and arm64
(each one on a native runner, joined in a multi-arch manifest).

The image tag is the version of the software packaged in it, read from the default value of the `ARG` in each Dockerfile (to change a version, edit the `ARG`). There is no `latest` tag and no git tag:

| Image | Source of the version | Example tag |
|---|---|---|
| `nginx` | `NGINX_VERSION` | `1.31.10` |
| `geoserver` | `GEOSERVER_VERSION` | `2.28.6` |
| `postgis` | `POSTGRES_VERSION`-`POSTGIS_VERSION` | `17-3.4` |
| `letsencrypt` | `LETSENCRYPT_VERSION` (certbot), in the workflow `env` | `2.6.0` |

- A push to `unifica-opengeosgb` publishes the images changed under `docker/<image>/` (all of them if the workflow changed). An already published version is overwritten by the same tag.
- Pull requests only build and scan the changed images.
- The manual run (`workflow_dispatch`) builds one image or `all`, and only publishes with `push` checked.
- On arm64, `postgis` is built on `docker.io/imresamu/postgis` (the official image is amd64 only).

Every image carries the OCI labels (`org.opencontainers.image.*`) set by the Dockerfiles from the `VERSION`, `REVISION` and `CREATED` build args.

Trivy scans each amd64 image and reports the HIGH/CRITICAL vulnerabilities with a fix in the job summary and in Code scanning. It does not block the publication (`SCAN_EXIT_CODE: '0'`); accepted ones go to `.trivyignore`, with a reason and an expiry date.

`.github/workflows/lint.yml` runs hadolint (`.hadolint.yaml`) on the Dockerfiles and shellcheck on the shell scripts, on pushes and pull requests to `unifica-opengeosgb`. Dependabot updates the GitHub Actions weekly (`.github/dependabot.yml`); the base images are bumped by hand.
