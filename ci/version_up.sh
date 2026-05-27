#!/usr/bin/env bash
# Increment branch patch counter in GitLab after a successful build.
# Uses VERSION_PATCH from version.mk artifact (the build that just finished).

set -euo pipefail

PATCH_NUM_VAR_NAME="P_$(echo "${CI_COMMIT_REF_SLUG}" | tr '-' '_')_PATCH_NUM"
VERSION_VAR_NAME="P_$(echo "${CI_COMMIT_REF_SLUG}" | tr '-' '_')_LAST_VERSION"

echo "${PATCH_NUM_VAR_NAME}"
echo "${VERSION_VAR_NAME}"

if [ ! -f version.mk ]; then
    echo "ERROR: version.mk not found (expected from amd64:linux.rwd.bld artifacts)" >&2
    exit 1
fi

# shellcheck source=/dev/null
source version.mk
CURRENT_VERSION="${VERSION_MAJOR}.${VERSION_MINOR}"
echo "Current version:${CURRENT_VERSION}"
echo "Built with patch:${VERSION_PATCH}"

if ! [[ "${VERSION_PATCH}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: VERSION_PATCH='${VERSION_PATCH}' from version.mk is not a non-negative integer" >&2
    exit 1
fi

PATCH_NUM=$((VERSION_PATCH + 1))
echo "New patch version:${PATCH_NUM}"

if [ -z "${ACCESS_TOKEN:-}" ]; then
    echo "ERROR: ACCESS_TOKEN is not set" >&2
    exit 1
fi

resp_file="$(mktemp)"
trap 'rm -f "$resp_file"' EXIT

http_code="$(
    curl -sS -o "${resp_file}" -w "%{http_code}" \
        --request PUT --header "PRIVATE-TOKEN: ${ACCESS_TOKEN}" \
        "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/variables/${PATCH_NUM_VAR_NAME}" \
        --form "key=${PATCH_NUM_VAR_NAME}" --form "value=${PATCH_NUM}" \
    || echo "000"
)"

if [ "${http_code}" != "200" ]; then
    echo "ERROR: failed to update ${PATCH_NUM_VAR_NAME}: HTTP ${http_code}: $(cat "${resp_file}")" >&2
    exit 1
fi

http_code="$(
    curl -sS -o "${resp_file}" -w "%{http_code}" \
        --request PUT --header "PRIVATE-TOKEN: ${ACCESS_TOKEN}" \
        "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/variables/${VERSION_VAR_NAME}" \
        --form "key=${VERSION_VAR_NAME}" --form "value=${CURRENT_VERSION}" \
    || echo "000"
)"

if [ "${http_code}" != "200" ]; then
    echo "ERROR: failed to update ${VERSION_VAR_NAME}: HTTP ${http_code}: $(cat "${resp_file}")" >&2
    exit 1
fi

echo "Updated ${PATCH_NUM_VAR_NAME}=${PATCH_NUM}, ${VERSION_VAR_NAME}=${CURRENT_VERSION}"
