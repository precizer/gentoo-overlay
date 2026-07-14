#!/bin/bash

# Stop on errors, reject unset variables, and propagate failures from pipelines
set -euo pipefail

# Resolve repository paths from this script so callers do not need a specific working directory
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly script_dir
overlay_dir=$(cd -- "${script_dir}/.." && pwd)
readonly overlay_dir

# Read the Docker settings exported by Make while keeping useful standalone defaults
readonly docker_command=${DOCKER:-docker}
readonly gentoo_image=${GENTOO_IMAGE:-gentoo/stage3:latest}
readonly gentoo_container=${GENTOO_CONTAINER:-precizer-gentoo-overlay}
readonly docker_label_key=${DOCKER_LABEL_KEY:-io.github.precizer.gentoo-overlay}
readonly docker_label_value=${DOCKER_LABEL_VALUE:-verification}

# Define every host and container location used by the verification workflow
readonly host_package_dir="${overlay_dir}/app-forensics/precizer"
readonly host_manifest="${host_package_dir}/Manifest"
readonly container_script_source="${script_dir}/verify-precizer-ebuild.sh"
readonly container_repository=/var/db/repos/precizer
readonly container_package_dir="${container_repository}/app-forensics/precizer"
readonly container_staged_package_dir=/tmp/precizer-package
readonly container_script=/tmp/verify-precizer-ebuild.sh
readonly package_atom=app-forensics/precizer::precizer

# Remember resources created by the current run so traps can remove exactly those resources
container_id=
manifest_tmp=

##
# @brief Run Docker through the command selected by the user
#
# @param[in] arguments Arguments forwarded to Docker without modification
# @return The exit status reported by Docker
run_docker() {
	# Preserve each argument boundary when forwarding paths, labels, and command options
	"${docker_command}" "$@"
}

##
# @brief Remove temporary resources created by the current verification run
#
# @return Success even when best-effort cleanup cannot remove a resource
cleanup_run() {
	# Remove an unfinished host-side Manifest copy left by an interrupted transfer
	if [[ -n ${manifest_tmp} ]]; then
		rm -f -- "${manifest_tmp}" >/dev/null 2>&1 || true
	fi

	# Remove only the container whose exact ID was recorded after creation
	if [[ -n ${container_id} ]]; then
		run_docker rm -f "${container_id}" >/dev/null 2>&1 || true
	fi
}

##
# @brief Preserve the original result while cleaning up after normal exit or a signal
#
# @return This function terminates the script with the original exit status
on_exit() {
	# Capture the result before any cleanup command can replace it
	local exit_status=$?

	# Disable all lifecycle traps so cleanup cannot trigger the same handler recursively
	trap - EXIT HUP INT TERM

	# Remove temporary files and the container without masking the original result
	cleanup_run

	# Report the result of the verification command that initiated this exit
	exit "${exit_status}"
}

##
# @brief Remove a previous project-owned container with the configured name
#
# @return Success when no container exists or the labeled container was removed
# @return Failure when Docker fails or the matching container does not carry the project label
remove_stale_container() {
	# Keep the exact container ID and its ownership label separate for clear validation
	local actual_label
	local container_name_pattern
	local existing_id

	# Escape dots before using the configured name in Docker's regular-expression filter
	container_name_pattern=${gentoo_container//./\\.}

	# Ask Docker for an exact name match and let daemon or permission errors propagate
	existing_id=$(run_docker ps -aq --filter "name=^/${container_name_pattern}$")

	# Finish successfully when there is no previous container to clean up
	if [[ -z ${existing_id} ]]; then
		return 0
	fi

	# Read the ownership label before allowing any destructive container operation
	actual_label=$(run_docker inspect --format "{{ index .Config.Labels \"${docker_label_key}\" }}" "${existing_id}")

	# Protect unrelated containers that happen to use the same configured name
	if [[ ${actual_label} != "${docker_label_value}" ]]; then
		printf 'Refusing to remove container %s without the expected project label\n' "${gentoo_container}" >&2
		return 1
	fi

	# Remove the verified project container so the new run starts from a clean name
	run_docker rm -f "${existing_id}" >/dev/null
}

##
# @brief Run the complete host-side Docker workflow for the Precizer ebuild
#
# @return Success only after repository preparation and both package lifecycle checks pass
run_verification() {
	# Always clean up the current container and preserve conventional signal exit codes
	trap on_exit EXIT
	trap 'exit 129' HUP
	trap 'exit 130' INT
	trap 'exit 143' TERM

	# Confirm that both inputs exist before downloading an image or creating a container
	test -d "${host_package_dir}"
	test -f "${container_script_source}"

	# Clear a safe project-owned predecessor and obtain the requested Gentoo image
	remove_stale_container
	run_docker pull "${gentoo_image}"

	# Create a labeled container that stays alive while preparation and verification run
	container_id=$(run_docker create \
		--name "${gentoo_container}" \
		--label "${docker_label_key}=${docker_label_value}" \
		"${gentoo_image}" \
		/bin/bash -lc 'exec tail -f /dev/null')
	run_docker start "${container_id}" >/dev/null

	# Stage the local package and the guest script outside the synchronized repository
	run_docker exec "${container_id}" install -d "${container_staged_package_dir}"
	run_docker cp "${host_package_dir}/." "${container_id}:${container_staged_package_dir}/"
	run_docker cp "${container_script_source}" "${container_id}:${container_script}"

	# Let the guest script recreate the overlay and regenerate its Manifest in Gentoo
	run_docker exec "${container_id}" /bin/bash "${container_script}" \
		prepare "${container_staged_package_dir}" "${container_repository}"

	# Copy the verified Manifest beside its destination and replace the host file atomically
	manifest_tmp=$(mktemp "${host_package_dir}/.Manifest.tmp.XXXXXX")
	run_docker cp "${container_id}:${container_package_dir}/Manifest" "${manifest_tmp}"
	test -s "${manifest_tmp}"
	mv -f -- "${manifest_tmp}" "${host_manifest}"
	manifest_tmp=

	# Run both install, smoke-test, and removal cycles inside the prepared container
	run_docker exec "${container_id}" /bin/bash "${container_script}" verify "${package_atom}"

	# Print a concise confirmation only after every required check has succeeded
	printf 'Gentoo package lifecycle verification completed\n'
}

##
# @brief Show the supported host-side actions
#
# @return The status of the output operation
usage() {
	# Keep the command syntax short enough to be useful in an error message
	printf 'Usage: %s {run|clean}\n' "$0" >&2
}

# Select the requested host-side action without evaluating command text from the caller
case ${1:-} in
	run)
		# Reject extra arguments so accidental input cannot alter the fixed workflow
		if (( $# != 1 )); then
			usage
			exit 2
		fi

		# Start the complete Docker-based verification workflow
		run_verification
		;;
	clean)
		# Keep cleanup predictable by accepting no additional arguments
		if (( $# != 1 )); then
			usage
			exit 2
		fi

		# Remove only a matching container that carries the expected project label
		remove_stale_container
		;;
	*)
		# Explain valid actions and use a conventional command-line usage status
		usage
		exit 2
		;;
esac
