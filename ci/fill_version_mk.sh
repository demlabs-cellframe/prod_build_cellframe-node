#!/usr/bin/env bash
# Resolve VERSION_PATCH from GitLab CI/CD variables and write version.mk.
# Fails the job on GitLab API errors instead of silently using patch 0.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../.." && pwd)"
GET_VAR="${HERE}/gitlab_project_var.sh"

PATCH_NUM_VAR_NAME="P_$(echo "${CI_COMMIT_REF_SLUG}" | tr '-' '_')_PATCH_NUM"
VERSION_VAR_NAME="P_$(echo "${CI_COMMIT_REF_SLUG}" | tr '-' '_')_LAST_VERSION"

echo "${PATCH_NUM_VAR_NAME}"
echo "${VERSION_VAR_NAME}"

# shellcheck source=/dev/null
source "${ROOT}/version.mk"
CURRENT_VERSION="${VERSION_MAJOR}.${VERSION_MINOR}"
echo "Current version from version.mk:${CURRENT_VERSION}"

read_var() {
    local name="$1"
    local __out_var="$2"
    local rc=0
    local value=""

    set +e
    value="$("${GET_VAR}" "${name}")"
    rc=$?
    set -e

    if [ "${rc}" -eq 0 ]; then
        printf -v "${__out_var}" '%s' "${value}"
        return 0
    fi
    if [ "${rc}" -eq 2 ]; then
        printf -v "${__out_var}" '%s' ""
        return 2
    fi
    return 1
}

STORED_VERSION=""
STORED_VERSION_RC=0
read_var "${VERSION_VAR_NAME}" STORED_VERSION || STORED_VERSION_RC=$?
if [ "${STORED_VERSION_RC}" -eq 1 ]; then
    exit 1
fi

echo "Stored version from GitLab:${STORED_VERSION}"

if [ -z "${STORED_VERSION}" ]; then
    echo "First build for this branch - starting with patch number 0"
    PATCH_NUM=0
elif [ "${STORED_VERSION}" != "${CURRENT_VERSION}" ]; then
    echo "Version changed from ${STORED_VERSION} to ${CURRENT_VERSION} - resetting patch number to 0"
    PATCH_NUM=0
else
    PATCH_NUM=""
    PATCH_NUM_RC=0
    read_var "${PATCH_NUM_VAR_NAME}" PATCH_NUM || PATCH_NUM_RC=$?
    if [ "${PATCH_NUM_RC}" -eq 1 ]; then
        exit 1
    fi

    echo "Gitlab var patch number for ${PATCH_NUM_VAR_NAME} is ${PATCH_NUM}."

    if [ "${PATCH_NUM_RC}" -eq 2 ] || [ -z "${PATCH_NUM}" ]; then
        echo "ERROR: ${PATCH_NUM_VAR_NAME} is missing or empty while ${VERSION_VAR_NAME}=${STORED_VERSION}. Refusing to build with patch 0 (possible GitLab API failure)." >&2
        exit 1
    fi
    if ! [[ "${PATCH_NUM}" =~ ^[0-9]+$ ]]; then
        echo "ERROR: ${PATCH_NUM_VAR_NAME}='${PATCH_NUM}' is not a non-negative integer" >&2
        exit 1
    fi
fi

{
    echo "VERSION_MAJOR=${VERSION_MAJOR}"
    echo "VERSION_MINOR=${VERSION_MINOR}"
    echo "VERSION_PATCH=${PATCH_NUM}"
} > "${ROOT}/version.mk"

cat "${ROOT}/version.mk"

curl -s --request POST --header "PRIVATE-TOKEN: ${ACCESS_TOKEN}" \
    "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/variables" \
    --form "key=${PATCH_NUM_VAR_NAME}" --form "value=${PATCH_NUM}" || true

curl -s --request POST --header "PRIVATE-TOKEN: ${ACCESS_TOKEN}" \
    "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/variables" \
    --form "key=${VERSION_VAR_NAME}" --form "value=${CURRENT_VERSION}" || true

PIPLINE_NAME="Build ${CURRENT_VERSION}-${PATCH_NUM}: ${CI_COMMIT_MESSAGE}"
curl -H "Job-Token: ${CI_JOB_TOKEN}" -X PUT \
    --data "name=${PIPLINE_NAME}" \
    "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/pipelines/${CI_PIPELINE_ID}/metadata"
