#!/usr/bin/env bash
# Copyright (c) 2017 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

SCRIPT_DIR=$(dirname $(realpath ${BASH_SOURCE[0]}))

. ${SCRIPT_DIR}/../globals.sh
. ${SCRIPT_DIR}/../common.sh

BUILDER_CONF=${BUILDER_CONF:-"${SCRIPT_DIR}/builder.conf"}
IMAGE_TEMPLATE=${IMAGE_TEMPLATE:-"${SCRIPT_DIR}/release-image-config.json"}

update_image_template() {
    bundles=""
    for bundle in $(/usr/bin/ls mix-bundles); do
        if [ ! -z "${bundles}" ]; then
            bundles+=", "
        fi
        bundles+="\"${bundle}\""
    done
    bundles="\"Bundles\": [${bundles}]"

    cat ${IMAGE_TEMPLATE} | sed "s/\"Bundles\":.*/${bundles}/" > ${IMAGE_TEMPLATE}.new
    /usr/bin/mv ${IMAGE_TEMPLATE} ${IMAGE_TEMPLATE}.$(date +%Y%m%d.%H%M%S)
    /usr/bin/mv ${IMAGE_TEMPLATE}.new ${IMAGE_TEMPLATE}
}

main() {
    test_dir ${BUILD_DIR}
    pushd ${BUILD_DIR} > /dev/null

    echo ""
    echo "Generating image template ..."
    update_image_template

    echo ""
    echo "Generating release image  ..."
    CURRENT_FORMAT=$(grep '^FORMAT' ${BUILDER_CONF} | awk -F= '{print $NF}')
    # Requires mixer 3.1.2 (https://github.com/mdhorn/mixer-tools.git integration)
    sudo -E mixer build-image -config ${BUILDER_CONF} -template ${IMAGE_TEMPLATE} -format ${CURRENT_FORMAT}

    mixversion=$(cat .mixversion)
    mkdir -p releases
    sudo -E /usr/bin/mv release.img releases/release-${mixversion}.img

    popd > /dev/null
}

main