#!/bin/sh

DIRNAME=$(dirname $0)

MANIFEST="${DIRNAME}/Manifest"

ORG=apple-oss-distributions

HOST=github.com
METHOD=https://

echo "Reading Manifest at '${MANIFEST}'..."

cat ${MANIFEST} | while read target; do
    TARGET=(${target})

    if [[ -d "${DIRNAME}/${TARGET[0]}" ]]; then
        echo "Directory exists at location '${DIRNAME}/${TARGET[0]}'. Skipping ${TARGET[0]}-${TARGET[1]}..."
    else
        echo "Fetching ${TARGET[0]}-${TARGET[1]} from ${ORG}..."

        git -C "${DIRNAME}" clone ${METHOD}${HOST}/${ORG}/${TARGET[0]}.git -b ${TARGET[0]}-${TARGET[1]}
    fi
done

MANIFEST_LLVM="${DIRNAME}/Manifest-llvm"

if [[ -d "${DIRNAME}/llvm-project" ]]; then
    echo "Directory exists at location '${DIRNAME}/${LLVM_INFO[0]}'. Skipping llvm-project..."
else
    LLVM_INFO=($(cat ${MANIFEST_LLVM}))
    LLVM_TARGET=${LLVM_INFO[0]}
    LLVM_BRANCH=${LLVM_INFO[1]}

    echo "Fetching llvm-project..."

    git -C "${DIRNAME}" clone ${METHOD}${HOST}/${LLVM_TARGET}.git -b "${LLVM_BRANCH}"
fi

