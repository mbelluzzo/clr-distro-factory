#!/usr/bin/env bash
# Copyright (C) 2018 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# shellcheck source=common.sh
# shellcheck disable=2162

set -e

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

. "${SCRIPT_DIR}/../common.sh"

. ./config/config.sh

var_load DISTRO_FORMAT
var_load DISTRO_LATEST
var_load MIX_FORMAT
var_load MIX_VERSION

calculate_diffs() {
    local packages_path
    local -A packages

    # Collecting package data for old version
    if [[ -n ${DISTRO_LATEST} ]]; then
        packages_path=${STAGING_DIR}/releases/${DISTRO_LATEST}/${PKG_LIST_FILE}-${DISTRO_LATEST}.txt
        assert_file "${packages_path}"

        old_package_list=$(sed -r 's/(.*)-(.*-.*)/\1\t\2/' "${packages_path}")
    else
        old_package_list=""
    fi
    while read NO VRO ; do
        packages[${NO}]="${VRO}"
    done <<< $old_package_list

    # Collecting package data for new version
    packages_path=${WORK_DIR}/${PKG_LIST_FILE}
    if [[ -f ${packages_path} ]]; then
        new_package_list=$(sed -r 's/(.*)-(.*-.*)/\1\t\2/' "${packages_path}")
    else
        new_package_list=""
    fi

    # Find added & changed packages
    while read NN VRN ; do
        if [[ ${packages[${NN}]+_} ]]; then
            if [[ "${packages[${NN}]}" != "${VN}-${RN}" ]]; then
                pkgs_changed+=$(printf "\\n    %s    %s -> %s" "${NN}" "${VRO}" "${VRN}")
            fi

            unset packages["${NN}"]
        else
            pkgs_added+=$(printf "\\n    %s    %s" "${NN}" "${VRN}")
        fi
    done <<< $new_package_list

    # Find removed packages
    for NO in "${!packages[@]}"; do
        pkgs_removed+=$(printf "\\n    %s    %s" "${NO}" "${packages[${NO}]}")
    done
}

generate_release_notes() {
    calculate_diffs

    cat > ${RELEASE_NOTES} << EOL
Release Notes for ${MIX_VERSION}

DISTRIBUTION VERSION:
    ${MIX_VERSION} (${MIX_FORMAT})

EOL

    if [[ -n ${DISTRO_LATEST} ]]; then
        log "PREVIOUS VERSION" \
            "${DISTRO_VERSION} (${DISTRO_FORMAT})" >> ${RELEASE_NOTES}
        log_line >> ${RELEASE_NOTES}
    fi

    cat >> ${RELEASE_NOTES} << EOL
ADDED PACKAGES:
${pkgs_added:-"    None"}

REMOVED PACKAGES:
${pkgs_removed:-"    None"}

UPDATED PACKAGES:
${pkgs_changed:-"    None"}
EOL
}

# ==============================================================================
# MAIN
# ==============================================================================
pushd "${WORK_DIR}" > /dev/null
log "Generating Release Notes"
generate_release_notes
log_line "Done!" 1
popd > /dev/null
