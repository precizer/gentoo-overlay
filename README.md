# Gentoo repository for Precizer

[Русская версия](README.ru.md)

This repository is an external Gentoo ebuild repository for installing Precizer through Portage

Precizer is a lightweight, high-performance CLI tool written in C for file integrity verification and comparison. It walks directory trees, calculates SHA512 checksums, and stores the results in an SQLite database. Databases can be compared with each other to find missing files and files with different contents

The tool is useful for validating synchronization results, backups, and Disaster Recovery scenarios. Precizer does not modify, delete, or move the files being checked. All working data is written only to the Precizer database

## Repository Setup

Root privileges are required for the following commands

### Setup through the Gentoo Repository Registry

The `precizer` overlay is registered in the Gentoo-maintained registry of third-party ebuild repositories. This is the primary setup method

```sh
emerge --ask app-eselect/eselect-repository
eselect repository enable precizer
emaint sync -r precizer
```

Registry inclusion allows `eselect repository` to obtain a ready-to-use overlay configuration without manually creating a local repository

### Alternative Manual Setup

As an alternative, the overlay can be enabled by manually creating and subsequently maintaining a local repository

```sh
emerge --ask --noreplace dev-vcs/git
install -d /etc/portage/repos.conf
cat >/etc/portage/repos.conf/precizer.conf <<'EOF'
[precizer]
location = /var/db/repos/precizer
sync-type = git
sync-uri = https://github.com/precizer/gentoo-overlay.git
auto-sync = yes
EOF
emaint sync --repo precizer
```

## Precizer Installation

The following commands install Precizer and verify that it is available system-wide

```sh
emerge --ask app-forensics/precizer
precizer --version
```

## Precizer Updates

The overlay is synchronized first

```sh
emaint sync --repo precizer
```

The package is then updated in the usual way

```sh
emerge --ask --update app-forensics/precizer
```

`emerge --sync` also synchronizes this repository because `auto-sync = yes` is enabled for it

### Optional Test Run

If desired, the tests included with Precizer can also be run during an update. A regular update does not require them

```sh
USE="test" FEATURES="test" emerge --ask --update app-forensics/precizer
```

In this command, `USE=test` enables the ebuild test phase, while `FEATURES=test` tells Portage to run it during the build

## Precizer Removal

Precizer is removed through Portage with the following command

```sh
emerge --ask --depclean app-forensics/precizer
```

## Overlay Disabling and Removal

### Overlay Enabled through the Gentoo Registry

The overlay can be disabled while retaining its downloaded files

```sh
eselect repository disable precizer
```

If the downloaded copy is no longer needed, complete removal is used instead of `disable`

```sh
eselect repository remove precizer
```

### Manually Created Overlay

After removing Precizer, the manually created configuration and local overlay copy can also be removed

```sh
rm -f /etc/portage/repos.conf/precizer.conf
rm -rf /var/db/repos/precizer
```

## Contributing to the Precizer Overlay

New Precizer versions, `Manifest` updates, and ebuild verification are documented in the [contributor guide](CONTRIBUTING.md)

## Links

- Main project: https://github.com/precizer/precizer
- Project site: https://precizer.github.io/
- Bugs and feature requests: https://github.com/precizer/precizer/issues
- Gentoo ebuild repository registry: https://overlays.gentoo.org/
- `eselect repository` documentation: https://wiki.gentoo.org/wiki/Eselect-repository
