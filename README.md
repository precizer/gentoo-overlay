# Gentoo repository for Precizer

[Русская версия](README.ru.md)

This repository is an external Gentoo ebuild repository for installing Precizer through Portage

Precizer is a lightweight, high-performance CLI tool written in C for file integrity verification and comparison. It walks directory trees, calculates SHA512 checksums, and stores the results in an SQLite database. Databases can be compared with each other to find missing files and files with different contents

The tool is useful for validating synchronization results, backups, and Disaster Recovery scenarios. Precizer does not modify, delete, or move the files being checked. All working data is written only to the Precizer database

## Repository Setup

Root privileges are required for the following commands

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

Precizer installation and command availability verification are performed as follows

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

The `test` USE flag and the `test` Portage feature are used for an update that includes the test phase

```sh
USE="test" FEATURES="test" emerge --ask --update app-forensics/precizer
```

`USE=test` permits the ebuild test phase, while `FEATURES=test` enables its execution during the build

`emerge --sync` also synchronizes this repository because `auto-sync = yes` is enabled for it

## Precizer Removal

Precizer is removed through Portage with the following command

```sh
emerge --ask --depclean app-forensics/precizer
```

## Overlay Removal

After Precizer has been removed, the configuration and local overlay copy are removed as follows

```sh
rm -f /etc/portage/repos.conf/precizer.conf
rm -rf /var/db/repos/precizer
```

## Contributing to the Overlay

New Precizer versions, `Manifest` updates, and ebuild verification are documented in the [contributor guide](CONTRIBUTING.md)

## Links

- Main project: https://github.com/precizer/precizer
- Project site: https://precizer.github.io/
- Bugs and feature requests: https://github.com/precizer/precizer/issues
