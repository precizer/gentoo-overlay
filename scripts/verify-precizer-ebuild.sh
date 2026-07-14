#!/bin/bash

# Stop on errors, reject unset variables, and propagate failures from pipelines
set -euo pipefail

# Reuse quiet, non-interactive emerge options for every package lifecycle operation
readonly -a emerge_common=(
	--ignore-default-opts
	--ask=n
	--autounmask=n
	--nospinner
	--color=n
)

##
# @brief Recreate the local overlay package and regenerate its Manifest inside Gentoo
#
# @param[in] staged_package_dir Package files copied into the container by the host script
# @param[in] repository_dir Local overlay directory configured for Portage
# @return Success after Portage regenerates a non-empty Manifest for all ebuilds
prepare_repository() {
	# Bind the two input paths and prepare storage for discovered ebuild files
	local staged_package_dir=$1
	local repository_dir=$2
	local package_dir="${repository_dir}/app-forensics/precizer"
	local distdir
	local ebuild_file
	local -a ebuild_files=()

	# Reject a staging path that is relative or points at the filesystem root
	if [[ ${staged_package_dir} != /* || ${staged_package_dir} == / ]]; then
		printf 'Refusing unsafe staging directory: %s\n' "${staged_package_dir}" >&2
		return 1
	fi

	# Reject an unsafe repository path before configuring Portage and replacing its package subtree
	if [[ ${repository_dir} != /* || ${repository_dir} == / ]]; then
		printf 'Refusing unsafe repository directory: %s\n' "${repository_dir}" >&2
		return 1
	fi

	# Bootstrap the main Gentoo repository and disable sandbox features unavailable in Docker
	install -d /var/db/repos/gentoo
	printf '%s\n' 'FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox"' >> /etc/portage/make.conf
	( emerge-webrsync -q || emerge --ignore-default-opts --sync )

	# Install Git from the binary package host when possible so the overlay can be synchronized
	emerge --ignore-default-opts --ask=n --nospinner --color=n --getbinpkg --noreplace dev-vcs/git

	# Configure the Precizer overlay exactly as documented for Gentoo users
	install -d /etc/portage/repos.conf
	printf '%s\n' \
		'[precizer]' \
		"location = ${repository_dir}" \
		'sync-type = git' \
		'sync-uri = https://github.com/precizer/gentoo-overlay.git' \
		'auto-sync = yes' \
		> /etc/portage/repos.conf/precizer.conf

	# Synchronize repository metadata before replacing only the package under test
	emaint sync --repo precizer

	# Replace the synchronized package with the exact files supplied by the local checkout
	test -d "${staged_package_dir}"
	rm -rf -- "${package_dir}"
	install -d "${package_dir}"
	cp -a -- "${staged_package_dir}/." "${package_dir}/"

	# Ask Portage for its distfile cache and reject empty or relative paths
	distdir=$(portageq envvar DISTDIR)
	if [[ -z ${distdir} || ${distdir} != /* ]]; then
		printf 'Refusing unsafe DISTDIR: %s\n' "${distdir}" >&2
		return 1
	fi

	# Resolve dot segments and symlinks before deciding whether deletion is safe
	distdir=$(realpath -m -- "${distdir}")

	# Never allow cache cleanup to target the filesystem root after canonicalization
	if [[ ${distdir} == / ]]; then
		printf 'Refusing unsafe DISTDIR: %s\n' "${distdir}" >&2
		return 1
	fi

	# Clear every cached distfile so changed pre-release archives are downloaded again
	install -d "${distdir}"
	find "${distdir}" -mindepth 1 -delete

	# Discover ebuilds without leaving an unmatched wildcard in the array
	shopt -s nullglob
	ebuild_files=("${package_dir}"/*.ebuild)
	shopt -u nullglob

	# Stop with a clear error instead of silently producing an empty package Manifest
	if (( ${#ebuild_files[@]} == 0 )); then
		printf 'No ebuild files found in %s\n' "${package_dir}" >&2
		return 1
	fi

	# Download each ebuild's original archive and let Portage calculate canonical hashes
	for ebuild_file in "${ebuild_files[@]}"; do
		GENTOO_MIRRORS= ebuild --ignore-default-opts --force --color=n "${ebuild_file}" manifest
	done

	# Require a usable result before the host script is allowed to copy the Manifest back
	test -s "${package_dir}/Manifest"
}

##
# @brief Build and install Precizer from source with the requested test settings
#
# @param[in] package_atom Fully qualified Portage package atom
# @param[in] features Portage FEATURES value for this installation
# @param[in] use_flags USE flags applied to this installation
# @return The exit status reported by emerge
install_precizer() {
	# Bind the lifecycle settings explicitly so each verification cycle is easy to read
	local package_atom=$1
	local features=$2
	local use_flags=$3

	# Disable local and remote binary packages so this step always verifies a source build
	FEATURES="${features}" USE="${use_flags}" emerge "${emerge_common[@]}" --usepkg=n --getbinpkg=n "${package_atom}"
}

##
# @brief Remove Precizer and confirm that no system-wide command remains available
#
# @param[in] package_atom Fully qualified Portage package atom to remove
# @return Success only when depclean succeeds and Precizer disappears from PATH
remove_precizer() {
	# Keep the target atom local to this removal cycle
	local package_atom=$1

	# Ask Portage to remove the installed package and update its dependency state
	emerge "${emerge_common[@]}" --depclean "${package_atom}"

	# Clear Bash's command cache so the PATH check reflects the current filesystem
	hash -r

	# Fail when the executable is still reachable after Portage reports successful removal
	if command -v precizer >/dev/null 2>&1; then
		printf 'precizer is still available after removal\n' >&2
		return 1
	fi
}

##
# @brief Verify normal installation and test-enabled installation as complete lifecycles
#
# @param[in] package_atom Fully qualified Portage package atom to verify
# @return Success only when both install, smoke-test, and removal cycles pass
verify_package() {
	# Keep one package identity across both lifecycle checks
	local package_atom=$1

	# First verify the normal user installation without running the ebuild test phase
	install_precizer "${package_atom}" '-test -getbinpkg' '-test'

	# Confirm that the installed executable is available through the system PATH
	precizer --version

	# Remove the normal installation and confirm that its command disappears
	remove_precizer "${package_atom}"

	# Rebuild from source with both the USE flag and Portage test feature enabled
	install_precizer "${package_atom}" 'test -getbinpkg' 'test'

	# Repeat the same system-wide smoke test after the test-enabled installation
	precizer --version

	# Remove the tested installation and confirm that its command disappears again
	remove_precizer "${package_atom}"
}

##
# @brief Show the supported in-container actions and their required arguments
#
# @return The status of the final output operation
usage() {
	# Present preparation and verification forms on separate lines for quick troubleshooting
	printf 'Usage: %s prepare STAGING_DIRECTORY REPOSITORY_DIRECTORY\n' "$0" >&2
	printf '       %s verify PACKAGE_ATOM\n' "$0" >&2
}

# Dispatch only the two fixed actions expected from the host-side controller
case ${1:-} in
	prepare)
		# Require both directories so destructive operations never receive missing values
		if (( $# != 3 )); then
			usage
			exit 2
		fi

		# Recreate the overlay and its Manifest before any package lifecycle checks
		prepare_repository "$2" "$3"
		;;
	verify)
		# Require one explicit package atom for the two controlled lifecycle checks
		if (( $# != 2 )); then
			usage
			exit 2
		fi

		# Run normal and test-enabled installation workflows for the selected package
		verify_package "$2"
		;;
	*)
		# Explain valid actions and use a conventional command-line usage status
		usage
		exit 2
		;;
esac
