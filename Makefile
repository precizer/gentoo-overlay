# These settings can be overridden on the make command line to use another Docker setup
DOCKER ?= docker
GENTOO_IMAGE ?= gentoo/stage3:latest
GENTOO_CONTAINER ?= precizer-gentoo-overlay
DOCKER_LABEL_KEY ?= io.github.precizer.gentoo-overlay
DOCKER_LABEL_VALUE ?= verification

# Make the selected Docker settings available to the host-side controller script
export DOCKER GENTOO_IMAGE GENTOO_CONTAINER DOCKER_LABEL_KEY DOCKER_LABEL_VALUE

# Keep lifecycle targets from operating on the same named container in parallel
.NOTPARALLEL:

# Treat every user-facing target as an action rather than a file name
.PHONY: all clean docker-gentoo docker-clean-gentoo

# Run the complete package verification workflow when no target is specified
all: docker-gentoo

# Verify local and Gentoo-registry package lifecycles in a fresh container
docker-gentoo:
	@scripts/docker-gentoo.sh run

# Remove the project-owned verification container if it still exists
docker-clean-gentoo:
	@scripts/docker-gentoo.sh clean

# Provide the conventional clean target as an alias for Docker cleanup
clean: docker-clean-gentoo
