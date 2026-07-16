# Contributing to the Precizer Gentoo Overlay

[Русская версия](CONTRIBUTING.ru.md)

This document describes how new Precizer versions are added, how the `Manifest` is updated, and how the complete Gentoo package lifecycle is verified

## Adding a New Version

A new version is prepared through the following stages

1. An ebuild named `precizer-X.Y.Z.ebuild` is created in `app-forensics/precizer/`, where `X.Y.Z` matches the version of the Precizer source archive
2. The build targets, test targets, dependencies, and installed file path are checked against the corresponding main-project release
3. The `Manifest` is not edited manually because the automated build regenerates it for every ebuild in the directory
4. After the ebuild is prepared, `make` is run from the repository root
5. After successful verification, the change set will contain the new or modified ebuild and the updated `app-forensics/precizer/Manifest`

Changes do not need to be published to the remote repository before verification. The automation uses the current local files from `app-forensics/precizer/`

## Automated Package Verification in Docker

The workflow requires GNU Make, Docker, and network connectivity. By default, it uses the `gentoo/stage3:latest` image and creates a temporary container named `precizer-gentoo-overlay`

The following command is run from the repository root

```sh
make
```

The default `all` target invokes the `docker-gentoo` target. Local working-copy preparation, `Manifest` regeneration, two local package verification cycles, and two published package verification cycles through the Gentoo registry are performed inside Docker

Verification consists of the following stages

1. A leftover project container is safely removed, the Gentoo image is pulled or updated, and a new container is created with a label marking it as part of the current workflow
2. The main Gentoo repository is synchronized in the container, and Git is installed together with `app-eselect/eselect-repository`
3. The overlay is enabled through the alternative manual `repos.conf` method and synchronized with the upstream Git repository
4. The package directory is replaced with the local `app-forensics/precizer/` contents, so the first workflow verifies the current working copy
5. The container's entire distfile cache is cleared, the source archives for every local ebuild are downloaded again from the URLs declared by that ebuild, and Portage is then asked to regenerate the shared `Manifest`
6. The non-empty `Manifest` is copied from the container to a temporary file beside the local `Manifest` and then atomically replaces `app-forensics/precizer/Manifest`
7. The latest local package version is built from source without tests or binary packages, installed, smoke-tested with `precizer --version` without an explicit path, removed through Portage, and checked to ensure that the command is no longer available through `PATH`
8. The same local version is rebuilt from source with `USE=test` and `FEATURES=test`, passes the ebuild test phase, is installed, passes the smoke test again, is removed through Portage, and is checked again to ensure that the command is no longer available through `PATH`
9. The manual configuration and synchronized checkout are completely removed, after which Portage is checked for the absence of the `precizer` repository
10. The overlay is enabled again from the Gentoo-maintained registry with `eselect repository enable precizer` and synchronized with `emaint sync -r precizer`
11. The published checkout is checked for its path, repository name, origin, non-empty `Manifest`, and ebuild files. No local files are copied into this checkout, and its `Manifest` is not regenerated
12. The distfile cache is cleared again, and the latest published version is then built, installed, smoke-tested, removed, and checked for absence from `PATH`
13. The published version repeats the same lifecycle with `USE=test` and `FEATURES=test`
14. `eselect repository remove precizer` removes the registry-enabled configuration and checkout, after which their absence is verified
15. After success, failure, or a handled signal, a best-effort attempt is made to remove the temporary container

Distfile cleanup happens only inside the temporary container. In the local workflow, it makes changed source archives detectable before a release is published; in the registry workflow, it independently downloads the archives verified by the published `Manifest`. Within the working copy, the automation changes only `app-forensics/precizer/Manifest`

Any required-stage failure causes `make` to return a nonzero status. The local `Manifest` is copied to the host before all build checks, so successfully recalculated hashes remain available even if the local or registry workflow fails later

## Manual Installation with Tests

The `test` USE flag and the `test` Portage feature are used for a one-time ebuild check in an already enabled overlay

```sh
USE="test" FEATURES="test" emerge --ask app-forensics/precizer
precizer --version
```

`USE=test` permits the test phase for `app-forensics/precizer`, while `FEATURES=test` tells Portage that the tests must run during the build

## Verification Container Cleanup

The temporary container is normally removed by an automatic cleanup handler. A cleanup failure does not replace the result of the main verification, so the container can remain if Docker is unavailable at that moment. After a forced stop that prevents the handler from running, such as `SIGKILL` or a Docker restart, the leftover container can be removed with `make clean`

The following command is run from the repository root

```sh
make clean
```

`make clean` is an alias for the `docker-clean-gentoo` target. The command looks for the configured container name, checks its ownership label, and removes it only after its ownership by this project has been confirmed. A container with the same name but without the expected label remains unchanged

If no container exists, the command succeeds without making changes. The Docker image, ebuild files, and `Manifest` are not removed

## Repository Structure

```text
Makefile
scripts/
    docker-gentoo.sh
    verify-precizer-ebuild.sh
app-forensics/precizer/
metadata/
profiles/
```

`Makefile` provides the automated verification and cleanup targets. `scripts/docker-gentoo.sh` controls the container and returns the updated `Manifest` to the working copy. `scripts/verify-precizer-ebuild.sh` is copied into the container, prepares the overlay, and performs package verification. `app-forensics/precizer/` contains the ebuild and package metadata. `metadata/layout.conf` tells Portage that the overlay inherits the main Gentoo repository. `profiles/repo_name` sets the repository name to `precizer`
