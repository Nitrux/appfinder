#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
PACKAGE_VERSION="${PACKAGE_VERSION:?PACKAGE_VERSION must be supplied by CI}"
TARGET_ARCH="${TARGET_ARCH:-$(dpkg --print-architecture)}"

# MauiKit software MUST be built with CMake and ECM; NEVER use Meson.
build_dir="$repo_root/build"
cmake_dir="$build_dir/cmake"
stage_dir="$build_dir/package"
rm -rf "$cmake_dir" "$stage_dir"
mkdir -p "$build_dir"

cmake_args=(
    -DCMAKE_INSTALL_PREFIX=/usr
    -DKDE_INSTALL_LIBDIR="lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
    -DCMAKE_BUILD_TYPE=Release
)
if [ "$(dpkg-architecture -qDEB_HOST_ARCH)" = "amd64" ]; then
    cmake_args+=(-DCMAKE_CXX_FLAGS=-march=x86-64-v3)
fi

cmake -S "$repo_root" -B "$cmake_dir" "${cmake_args[@]}"
cmake --build "$cmake_dir" --parallel "$(nproc)"
DESTDIR="$stage_dir" cmake --install "$cmake_dir"

mkdir -p "$stage_dir/DEBIAN"
cat > "$stage_dir/DEBIAN/control" <<CONTROL
Package: appfinder
Version: ${PACKAGE_VERSION}
Section: utils
Priority: optional
Architecture: ${TARGET_ARCH}
Maintainer: uri_herrera@nxos.org
Provides: appfinder
Depends: libkf6coreaddons6,libkf6i18n6,libqt6core6t64,libqt6gui6,libqt6network6,libqt6qml6,libqt6quick6,libqt6widgets6,distrobox,libnotify-bin,libyaml-cpp0.9,mauikit (>= 4.0.5),qml6-module-qtquick,qml6-module-qtquick-controls,qml6-module-qtquick-layouts,qml6-module-qtquick-effects,flatpak,libpolkit-agent-1-0
Description: AppFinder application launcher.
 AppFinder application launcher.
CONTROL

dpkg-deb --build --root-owner-group "$stage_dir" "$build_dir/appfinder_${PACKAGE_VERSION}_${TARGET_ARCH}.deb"
