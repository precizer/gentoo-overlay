# Contributing to the Precizer Gentoo Overlay

[Русская версия](CONTRIBUTING.ru.md)

This document describes how new Precizer versions are added, how the `Manifest` is updated, and how the complete Gentoo package lifecycle is verified

## Adding a New Version

A new version is prepared through the following stages

1. An ebuild named `precizer-X.Y.Z.ebuild` is created in `app-forensics/precizer/`, where `X.Y.Z` matches the version of the Precizer source archive
2. The build targets, test targets, dependencies, and installed file path are checked against the corresponding main-project release
3. The `Manifest` is not edited manually because the automated build regenerates it for every ebuild in the directory
4. After the ebuild is prepared, `make` is run from the repository root. The command updates the `Manifest` and starts verification of builds, installation, and removal for the local and published package versions in Docker. Details are described in [Verifying Package Builds, Installation, and Removal](#verifying-package-builds-installation-and-removal)
5. After successful verification, the change set will contain the new or modified ebuild and the updated `app-forensics/precizer/Manifest`

Changes do not need to be published to the remote repository before verification. The automation uses the current local files copied into `app-forensics/precizer/`

## Verifying Package Builds, Installation, and Removal

Verification requires GNU Make, Docker, and network access. It is started from the repository root with the following command

```sh
make
```

The command creates a temporary Gentoo container based on the `gentoo/stage3:latest` image. The latest local package version from `app-forensics/precizer/` is checked first, followed by the latest published version from the overlay

Each version goes through two verification cycles: without tests and with tests enabled through `USE=test` and `FEATURES=test`. In each cycle, the package is built from source, installed, and checked by running `precizer --version`. The package is then removed through Portage, and the command is checked to ensure that it is no longer available through `PATH`

Verification includes the following stages

1. Gentoo is prepared inside the container, and the overlay is enabled manually through `repos.conf`
2. Local files from `app-forensics/precizer/` are copied into the overlay. Source archives for all local ebuilds are downloaded again, the `Manifest` is regenerated, and the local `app-forensics/precizer/Manifest` file is updated
3. The latest local package version goes through both verification cycles
4. The manual overlay configuration is removed. The overlay is enabled again from the Gentoo repository registry through `eselect repository enable precizer` and synchronized
5. The published overlay configuration and contents are checked. Source archives are downloaded again and verified against the published `Manifest`, after which the latest published version goes through both verification cycles
6. The overlay is removed through `eselect repository remove precizer`, and the absence of its configuration and files is verified

The source archive cache is cleared only inside the temporary container. Only `app-forensics/precizer/Manifest` is changed in the working copy. Verification of the published version uses files from the remote repository, and its `Manifest` is not regenerated

A failure at any required stage causes `make` to return a nonzero exit code. The local `Manifest` is updated before the package is built and is retained even if later checks fail

Removal of the temporary container is attempted automatically when verification ends, including after an error or a handled signal. If the container could not be removed, `make clean` is used to retry cleanup

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
