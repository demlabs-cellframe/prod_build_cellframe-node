#!/usr/bin/env bash
# Increment branch patch counter in GitLab after a successful build.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GET_VAR="${HERE}/gitlab_project_var.sh"

PATCH_NUM_VAR_NAME="P_$(echo "${CI_COMMIT_REF_SLUG}" | tr '-' '_')_PATCH_NUM"
VERSION_VAR_NAME="P_$(echo "${CI_COMMIT_REF_SLUG}" | tr '-' '_')_LAST_VERSION"

echo "${PATCH_NUM_VAR_NAME}"
echo "${VERSION_VAR_NAME}"

# shellcheck source=/dev/null
source version.mk
CURRENT_VERSION="${VERSION_MAJOR}.${VERSION_MINOR}"
echo "Current version:${CURRENT_VERSION}"

set +e
PATCH_NUM="$("${GET_VAR}" "${PATCH_NUM_VAR_NAME}")"
rc=$?
set -e

if [ "${rc}" -ne 0 ]; then
    echo "ERROR: cannot read ${PATCH_NUM_VAR_NAME} for version:up (exit ${rc})" >&2
    exit 1
fi

if [ -z "${PATCH_NUM}" ] || ! [[ "${PATCH_NUM}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: ${PATCH_NUM_VAR_NAME}='${PATCH_NUM}' is not a valid patch number" >&2
    exit 1
fi

PATCH_NUM=$((PATCH_NUM + 1))
echo "New patch version:${PATCH_NUM}"

http_code="$(
    curl -sS -o /tmp/version_up_patch_resp -w "%{http_code}" \
        --request PUT --header "PRIVATE-TOKEN: ${ACCESS_TOKEN}" \
        "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/variables/${PATCH_NUM_VAR_NAME}" \
        --form "key=${PATCH_NUM_VAR_NAME}" --form "value=${PATCH_NUM}" \
    || echo "000"
)"

if [ "${http_code}" != "200" ]; then
    echo "ERROR: failed to update ${PATCH_NUM_VAR_NAME}: HTTP ${http_code}: $(cat /tmp/version_up_patch_resp)" >&2
    exit 1
fi

http_code="$(
    curl -sS -o /tmp/version_up_ver_resp -w "%{http_code}" \
        --request PUT --header "PRIVATE-TOKEN: ${ACCESS_TOKEN}" \
        "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/variables/${VERSION_VAR_NAME}" \
        --form "key=${VERSION_VAR_NAME}" --form "value=${CURRENT_VERSION}" \
    || echo "000"
)"

if [ "${http_code}" != "200" ]; then
    echo "ERROR: failed to update ${VERSION_VAR_NAME}: HTTP ${http_code}: $(cat /tmp/version_up_ver_resp)" >&2
    exit 1
fi
