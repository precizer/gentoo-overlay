# Gentoo repository for Precizer

[Русская версия](README.ru.md)

This repository is an external Gentoo ebuild repository for installing Precizer through Portage

Precizer is a lightweight, high-performance CLI tool written in C for file integrity verification and comparison. It walks directory trees, calculates SHA512 checksums, and stores the results in an SQLite database. Databases can be compared with each other to find missing files and files with different contents

The tool is useful for validating synchronization results, backups, and Disaster Recovery scenarios. Precizer does not modify, delete, or move the files being checked. All working data is written only to the Precizer database

## Enable the Repository

Run the commands as `root`

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

## Install

```sh
emerge --ask app-forensics/precizer
precizer --version
```

## Install with Tests

To build the package and run the tests from the ebuild, enable the `test` USE flag and the `test` Portage feature for this invocation

```sh
USE="test" FEATURES="test" emerge --ask app-forensics/precizer
precizer --version
```

`USE=test` allows the test phase for `app-forensics/precizer`, and `FEATURES=test` tells Portage to actually run tests during the build

## Update

To update only this repository, use

```sh
emaint sync --repo precizer
```

After syncing, update the package in the usual way

```sh
emerge --ask --update app-forensics/precizer
```

`emerge --sync` will also synchronize this repository because `auto-sync = yes` is enabled for it

## Disable

```sh
emerge --ask --depclean app-forensics/precizer
rm -f /etc/portage/repos.conf/precizer.conf
rm -rf /var/db/repos/precizer
```

## Repository Structure

```text
app-forensics/precizer/
metadata/
profiles/
```

`app-forensics/precizer/` contains the ebuild and package metadata. `metadata/layout.conf` tells Portage that this overlay inherits the main Gentoo repository. `profiles/repo_name` sets the repository name to `precizer`

## Links

- Main project: https://github.com/precizer/precizer
- Project site: https://precizer.github.io/
- Bugs and feature requests: https://github.com/precizer/precizer/issues
