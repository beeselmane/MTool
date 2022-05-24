#!/bin/sh

SOURCE_DIR="${2}"
DEST_DIR="${1}"

availability_src="${SOURCE_DIR}/AvailabilityVersions"
cctools_src="${SOURCE_DIR}/cctools"
objc_src="${SOURCE_DIR}/objc4"
dyld_src="${SOURCE_DIR}/dyld"

private_incdir="${DEST_DIR}/private"
public_incdir="${DEST_DIR}/public"

tmpdir="${DERIVED_FILES_DIR}/tmp"

make_dyld_priv() {
    mkdir -p "${tmpdir}/usr/local/include/"{dyld,mach-o}
    mkdir -p "${private_incdir}/dyld"

    "${availability_src}/print_dyld_os_versions.rb" "${availability_src}/availability.pl" > "${private_incdir}/dyld/for_dyld_priv.inc"
    cp "${private_incdir}/dyld/for_dyld_priv.inc" "${tmpdir}/usr/local/include/dyld/for_dyld_priv.inc"

    DERIVED_FILES_DIR="${tmpdir}" DSTROOT="${tmpdir}" SRCROOT="${dyld_src}" SDKROOT="${tmpdir}" DRIVERKIT=0 \
        "${dyld_src}/build-scripts/libdyld-generate-version-headers.sh" 

    cp -v "${tmpdir}/usr/local/include/mach-o/dyld_priv.h" "${private_incdir}/mach-o/dyld_priv.h"
}

copy_cctools() {
    mkdir -p "${private_incdir}/dyld"
    mkdir -p "${private_incdir}/cbt"

    # From dyld_h dummy lib
    cp -v "${cctools_src}/include/stuff/bool.h" "${private_incdir}/dyld"

    # From macho_h_{x86_64,arm,arm64}
    #cp -v "${cctools_src}/include/mach-o/"{x86_64,arm,arm64}/reloc.h "${public_incdir}/mach-o"

    # From libsyminfo.a
    cp -v "${cctools_src}/include/cbt/libsyminfo.h" "${private_incdir}/cbt"

    # From libredo_prebinding.a
    cp -v "${cctools_src}/include/mach-o/redo_prebinding.h" "${private_incdir}/mach-o"
}

copy_dyld() {
    local private_headers=(dyld-interposing dyld_process_info dyld_introspection)

    # From libKernelCollectionBuilder.dylib
    cp -v "${dyld_src}/cache-builder/kernel_collection_builder.h" "${private_incdir}"

    # From libdsc.a
    cp -v "${dyld_src}/other-tools/"dsc_{extractor,iterator}.h "${private_incdir}/mach-o"

    # From libdyld aggregate
    cp -v "${dyld_src}/include/objc-shared-cache.h" "${private_incdir}"

    # From libdyld.dylib
    cp -v "${dyld_src}/cache-builder/dyld_cache_format.h" "${private_incdir}/mach-o"
    cp -v "${dyld_src}/include/dlfcn_private.h" "${private_incdir}"

    for f in "${private_headers[@]}"; do
        cp -v "${dyld_src}/include/mach-o/${f}.h" "${private_incdir}/mach-o"
    done

}

copy_objc4() {
    local private_headers=(maptable objc-abi objc-gdb objc-internal NSObject-internal)

    mkdir -p "${private_incdir}/objc"
    mkdir -p "${public_incdir}/objc"

    # From libobjc-tranmpolines.dylib
    cp -v "${objc_src}/runtime/objc-block-trampolines.h" "${private_incdir}/objc"

    # From libobjc.dylib
    for f in "${private_headers[@]}"; do
        cp -v "${objc_src}/runtime/${f}.h" "${private_incdir}/objc"
    done
}

# bridgeos availability macros are unavailable in the standard MacOS SDK.
# we need to remote them
sanitize_headers() {
    # We need to sanitize at least these headers
    local headers=(dyld_process_info dyld_priv dyld_introspection)

    # This annotation is only used here for now.
    sed -i '' 's/__API_UNAVAILABLE(bridgeos)//g' "${private_incdir}/mach-o/dyld_process_info.h"

    # This annotation is only used here.
    sed -i '' 's/__API_AVAILABLE(bridgeos([0-9]\.[0-9]))//g' "${private_incdir}/mach-o/dyld_priv.h"

    # Remove references from each of these files
    for f in "${headers[@]}"; do
        # Remove ', bridgeos(N.n, M.m)'
        sed -i '' 's/\, bridgeos([0-9]\.[0-9]\,[0-9]\.[0-9])//g' "${private_incdir}/mach-o/${f}.h"

        # Remove ', bridgeos(N.n)'
        sed -i '' 's/\, bridgeos([0-9]\.[0-9])//g' "${private_incdir}/mach-o/${f}.h"

        # Remove 'bridgeos N.n /' (from dyld_priv versions)
        sed -i '' 's/bridgeos [0-9]\.[0-9] \///g' "${private_incdir}/mach-o/${f}.h"

        # Remove remaining references
        sed -i '' 's/\,bridgeos//g' "${private_incdir}/mach-o/${f}.h"
    done
}

mkdir -p "${private_incdir}/mach-o"
mkdir -p "${public_incdir}/mach-o"
mkdir -p "${tmpdir}"

copy_cctools

copy_dyld
make_dyld_priv

copy_objc4

sanitize_headers
