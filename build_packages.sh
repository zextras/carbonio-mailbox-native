#!/bin/bash
#
# SPDX-FileCopyrightText: 2023 Zextras <https://www.zextras.com>
#
# SPDX-License-Identifier: GPL-2.0-only
#
OS=${1:-"ubuntu-jammy"}

echo "Building for OS: $OS"

docker run -it --rm \
    --entrypoint=/bin/sh \
    -v "$(pwd)/artifacts/${OS}":/artifacts \
    -v "$(pwd)":/tmp/build \
    "docker.io/m0rf30/yap-${OS}:1.8" \
    -c "cp /tmp/build/target/libnative.so /tmp/build/package/libnative.so && yap build ${OS} /tmp/build -s"
