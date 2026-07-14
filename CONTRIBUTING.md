# Contributing to the Precizer Gentoo Overlay

[Русская версия](CONTRIBUTING.ru.md)

This document describes how new Precizer versions are added, how the `Manifest` is updated, and how the complete Gentoo package lifecycle is verified

## Adding a New Version

A new version is prepared through the following stages

1. An ebuild named `precizer-X.Y.Z.ebuild` is created in `app-forensics/precizer/`, where `X.Y.Z` matches the version of the Precizer source archive
2. The build targets, test targets, dependencies, and installed file path are checked against the corresponding main-project release. A previous ebuild can be used as a basis only while the build process remains compatible
3. The `Manifest` is not edited manually because automated verification regenerates it for every ebuild in the directory
4. After the ebuild is prepared, `make` is run from the repository root
5. After successful verification, the change set should contain the new or modified ebuild and the updated `app-forensics/precizer/Manifest`

Changes do not need to be published to the remote repository before verification. The automation uses the current local files from `app-forensics/precizer/`

## Manual Installation with Tests

The `test` USE flag and the `test` Portage feature are used for a one-time ebuild check in an already enabled overlay

```sh
USE="test" FEATURES="test" emerge --ask app-forensics/precizer
precizer --version
```

`USE=test` permits the test phase for `app-forensics/precizer`, while `FEATURES=test` tells Portage that the tests must run during the build

## Automated Package Verification in Docker

The workflow requires GNU Make, the `docker` command, access to a running Docker daemon, and network connectivity. It uses the `gentoo/stage3:latest` image and a temporary container named `precizer-gentoo-overlay` by default

The following command is run from the repository root

```sh
make
```

The default `all` target invokes the `docker-gentoo` target. Local overlay preparation, `Manifest` regeneration, and two complete package verification cycles are performed inside Docker

Verification consists of the following stages

1. A leftover project container is safely removed, the Gentoo image is pulled or updated, and a new container is created with an ownership label
2. The main Gentoo repository is synchronized in the container, Git is installed, and the Precizer repository is enabled according to the [user documentation](README.md#repository-setup)
3. After synchronization, the package directory is replaced with the local `app-forensics/precizer/` contents, ensuring that the current working copy is tested
4. The container's entire distfile cache is cleared, the source archives for every ebuild are downloaded again from the URLs declared by that ebuild, and Portage is then asked to regenerate the shared `Manifest`
5. The non-empty `Manifest` is copied from the container to a temporary file beside the local `Manifest` and then atomically replaces `app-forensics/precizer/Manifest`
6. The latest available package version is built from source without tests or binary packages, installed, smoke-tested with `precizer --version` without an explicit path, removed through Portage, and checked for absence from `PATH`
7. The same version is rebuilt from source with `USE=test` and `FEATURES=test`, passes the ebuild test phase, is installed, passes the smoke test again, is removed through Portage, and is checked again for absence from `PATH`
8. After success, failure, or a handled signal, a best-effort attempt is made to remove the temporary container

Distfile cleanup happens only inside the temporary container and makes changed source archives detectable before a release is published. Within the working copy, the automation changes only `app-forensics/precizer/Manifest`

Any required-stage failure causes `make` to return a nonzero status. The `Manifest` is copied to the host before the build checks, so successfully recalculated hashes remain available even if a later build, test, or removal step fails

## Verification Container Cleanup

The temporary container is normally removed by an automatic cleanup handler. A cleanup failure does not replace the result of the main verification, so the container can remain if Docker is unavailable at that moment. `make clean` is also required after a forced stop that prevents the handler from running, such as `SIGKILL` or a Docker restart

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
