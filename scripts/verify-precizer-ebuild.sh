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

# Keep the repository identity and manually managed configuration path consistent across workflows
readonly repository_name=precizer
readonly manual_repository_config=/etc/portage/repos.conf/precizer.conf
readonly expected_repository_dir=/var/db/repos/precizer
readonly repository_sync_uri=https://github.com/precizer/gentoo-overlay.git

##
# @brief Confirm that Portage resolves the Precizer repository to the expected directory
#
# @param[in] expected_repository_dir Directory that should be registered for the repository
# @return Success only when Portage reports the exact expected directory
require_repository_path() {
	# Compare canonical paths so harmless dot segments or symlinks do not cause false failures
	local canonical_expected_repository_dir
	local reported_repository_dir
	canonical_expected_repository_dir=$(realpath -m -- "$1")
	reported_repository_dir=$(portageq get_repo_path / "${repository_name}")
	reported_repository_dir=$(realpath -m -- "${reported_repository_dir}")

	# Reject a repository registration that points anywhere other than the controlled directory
	if [[ ${reported_repository_dir} != "${canonical_expected_repository_dir}" ]]; then
		printf 'Repository %s resolves to %s instead of %s\n' \
			"${repository_name}" "${reported_repository_dir}" "${canonical_expected_repository_dir}" >&2
		return 1
	fi
}

##
# @brief Confirm that Portage no longer has a configured Precizer repository
#
# @return Success only when the repository has no path in the current Portage configuration
require_repository_absent() {
	# Obtain the complete repository list while allowing Portage errors to remain fatal
	local configured_repository
	local configured_repositories
	configured_repositories=$(portageq get_repos /)

	# Treat an exact repository-name match as an incomplete disconnect
	while IFS= read -r configured_repository; do
		if [[ ${configured_repository} == "${repository_name}" ]]; then
			printf 'Repository %s is still configured\n' "${repository_name}" >&2
			return 1
		fi
	done <<< "${configured_repositories}"
}

##
# @brief Remove every cached source archive from Portage's configured distfile directory
#
# @return Success only when DISTDIR resolves to a safe directory and its contents are removed
clear_distfiles() {
	# Ask Portage for its distfile cache and reject empty or relative paths
	local distdir
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

	# Clear every cached distfile so the next repository downloads and validates its own archives
	install -d "${distdir}"
	find "${distdir}" -mindepth 1 -delete
}

##
# @brief Recreate the manually configured overlay package and regenerate its Manifest inside Gentoo
#
# @param[in] staged_package_dir Package files copied into the container by the host script
# @param[in] repository_dir Local overlay directory configured for Portage
# @return Success after Portage regenerates a non-empty Manifest for all ebuilds
prepare_repository() {
	# Bind the two input paths and prepare storage for discovered ebuild files
	local staged_package_dir=$1
	local repository_dir=$2
	local package_dir="${repository_dir}/app-forensics/precizer"
	local ebuild_file
	local -a ebuild_files=()

	# Reject a staging path that is relative or points at the filesystem root
	if [[ ${staged_package_dir} != /* || ${staged_package_dir} == / ]]; then
		printf 'Refusing unsafe staging directory: %s\n' "${staged_package_dir}" >&2
		return 1
	fi

	# Accept only the dedicated container path before configuring or replacing repository contents
	if [[ ${repository_dir} != "${expected_repository_dir}" ]]; then
		printf 'Refusing unsafe repository directory: %s\n' "${repository_dir}" >&2
		return 1
	fi

	# Bootstrap the main Gentoo repository and disable sandbox features unavailable in Docker
	install -d /var/db/repos/gentoo
	printf '%s\n' 'FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox"' >> /etc/portage/make.conf
	( emerge-webrsync -q || emerge --ignore-default-opts --sync )

	# Install both repository setup tools from the binary package host when possible
	emerge --ignore-default-opts --ask=n --nospinner --color=n --getbinpkg --noreplace \
		dev-vcs/git app-eselect/eselect-repository

	# Configure the Precizer overlay through the documented alternative manual path
	install -d /etc/portage/repos.conf
	printf '%s\n' \
		"[${repository_name}]" \
		"location = ${repository_dir}" \
		'sync-type = git' \
		"sync-uri = ${repository_sync_uri}" \
		'auto-sync = yes' \
		> "${manual_repository_config}"

	# Synchronize repository metadata before replacing only the package under test
	emaint sync -r "${repository_name}"
	require_repository_path "${repository_dir}"

	# Replace the synchronized package with the exact files supplied by the local checkout
	test -d "${staged_package_dir}"
	rm -rf -- "${package_dir}"
	install -d "${package_dir}"
	cp -a -- "${staged_package_dir}/." "${package_dir}/"

	# Clear every cached distfile so changed pre-release archives are downloaded again
	clear_distfiles

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
# @brief Remove the manually configured repository and confirm that Portage forgets it
#
# @param[in] repository_dir Local overlay directory created by the manual synchronization
# @return Success only when the expected repository directory and its configuration are removed
remove_manual_repository() {
	# Bind and validate the destructive cleanup target before inspecting its registration
	local repository_dir=$1
	if [[ ${repository_dir} != "${expected_repository_dir}" ]]; then
		printf 'Refusing unsafe repository directory: %s\n' "${repository_dir}" >&2
		return 1
	fi

	# Refuse cleanup when the configured repository points outside the controlled directory
	require_repository_path "${repository_dir}"

	# Remove the manual configuration and synchronized checkout before the official workflow starts
	rm -f -- "${manual_repository_config}"
	rm -rf -- "${repository_dir}"

	# Require a clean Portage state so the official setup cannot reuse the manual registration
	require_repository_absent
	test ! -e "${repository_dir}"
}

##
# @brief Enable and synchronize the published Precizer overlay through the Gentoo registry
#
# @return Success only when eselect configures a non-empty repository checkout for Portage
prepare_official_repository() {
	# Reserve storage for the registry-selected path, remote URL, and published ebuild list
	local repository_dir
	local remote_uri
	local -a ebuild_files=()

	# Start from an unconfigured repository name so registry discovery is tested independently
	require_repository_absent

	# Use the Gentoo-maintained registry entry without writing or replacing repository contents
	eselect repository enable "${repository_name}"
	emaint sync -r "${repository_name}"

	# Require the registry to select the standard path used by the documented workflow
	require_repository_path "${expected_repository_dir}"
	repository_dir=$(portageq get_repo_path / "${repository_name}")

	# Verify that the synchronized checkout identifies itself as the Precizer repository
	test -f "${repository_dir}/profiles/repo_name"
	test "$(< "${repository_dir}/profiles/repo_name")" = "${repository_name}"

	# Verify that the Gentoo registry points at the expected upstream repository
	remote_uri=$(git -C "${repository_dir}" remote get-url origin)
	if [[ ${remote_uri} != "${repository_sync_uri}" ]]; then
		printf 'Repository %s uses unexpected origin %s\n' \
			"${repository_name}" "${remote_uri}" >&2
		return 1
	fi

	# Require an untouched published package with a usable Manifest and at least one ebuild
	test -s "${repository_dir}/app-forensics/precizer/Manifest"
	shopt -s nullglob
	ebuild_files=("${repository_dir}/app-forensics/precizer/"*.ebuild)
	shopt -u nullglob
	if (( ${#ebuild_files[@]} == 0 )); then
		printf 'No published ebuild files found in repository %s\n' "${repository_name}" >&2
		return 1
	fi

	# Force the published package to download and validate its own source archives
	clear_distfiles
}

##
# @brief Remove the registry-enabled Precizer overlay and confirm that no checkout remains
#
# @return Success only when eselect removes both the configuration and synchronized contents
remove_official_repository() {
	# Capture the exact standard path before asking eselect to remove it
	local repository_dir
	require_repository_path "${expected_repository_dir}"
	repository_dir=$(portageq get_repo_path / "${repository_name}")

	# Exercise the official removal path after both published-package lifecycles pass
	eselect repository remove "${repository_name}"

	# Verify that neither an active Portage registration nor downloaded contents were left behind
	require_repository_absent
	test ! -e "${repository_dir}"
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
	# Present every fixed workflow action on separate lines for quick troubleshooting
	printf 'Usage: %s prepare STAGING_DIRECTORY REPOSITORY_DIRECTORY\n' "$0" >&2
	printf '       %s verify PACKAGE_ATOM\n' "$0" >&2
	printf '       %s remove-manual REPOSITORY_DIRECTORY\n' "$0" >&2
	printf '       %s prepare-official\n' "$0" >&2
	printf '       %s remove-official\n' "$0" >&2
}

# Dispatch only the fixed lifecycle actions expected from the host-side controller
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
	remove-manual)
		# Require the exact directory so cleanup cannot receive a missing destructive target
		if (( $# != 2 )); then
			usage
			exit 2
		fi

		# Remove the manually synchronized checkout before registry-based verification
		remove_manual_repository "$2"
		;;
	prepare-official)
		# Keep registry setup deterministic by accepting no additional arguments
		if (( $# != 1 )); then
			usage
			exit 2
		fi

		# Enable and synchronize the untouched published overlay through eselect
		prepare_official_repository
		;;
	remove-official)
		# Keep registry cleanup deterministic by accepting no additional arguments
		if (( $# != 1 )); then
			usage
			exit 2
		fi

		# Remove the official repository registration and its synchronized checkout
		remove_official_repository
		;;
	*)
		# Explain valid actions and use a conventional command-line usage status
		usage
		exit 2
		;;
esac
