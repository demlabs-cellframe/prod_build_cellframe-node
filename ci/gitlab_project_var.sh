#!/usr/bin/env bash
# Read a GitLab project CI/CD variable via API v4.
# Requires: ACCESS_TOKEN, CI_API_V4_URL, CI_PROJECT_ID
#
# Usage: gitlab_project_var.sh <variable_key>
# Prints variable value to stdout.
# Exit codes:
#   0 ok
#   1 API/transport error
#   2 variable not found (404)
#   3 auth error (401/403 — expired/invalid ACCESS_TOKEN)

set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
    echo "Usage: gitlab_project_var.sh <variable_key>" >&2
    exit 1
fi

var_name="$1"

if [ -z "${ACCESS_TOKEN:-}" ]; then
    echo "ERROR: ACCESS_TOKEN is not set" >&2
    exit 3
fi

if [ -z "${CI_API_V4_URL:-}" ] || [ -z "${CI_PROJECT_ID:-}" ]; then
    echo "ERROR: CI_API_V4_URL or CI_PROJECT_ID is not set" >&2
    exit 1
fi

tmp_body="$(mktemp)"
trap 'rm -f "$tmp_body"' EXIT

http_code="$(
    curl -sS -o "$tmp_body" -w "%{http_code}" \
        --header "PRIVATE-TOKEN: ${ACCESS_TOKEN}" \
        "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/variables/${var_name}" \
    || echo "000"
)"

if [ "$http_code" = "000" ]; then
    echo "ERROR: curl failed while reading GitLab variable '${var_name}'" >&2
    exit 1
fi

if [ "$http_code" = "404" ]; then
    exit 2
fi

if [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
    echo "ERROR: GitLab variables API HTTP ${http_code} for '${var_name}': $(cat "$tmp_body")" >&2
    exit 3
fi

if [ "$http_code" != "200" ]; then
    echo "ERROR: GitLab variables API HTTP ${http_code} for '${var_name}': $(cat "$tmp_body")" >&2
    exit 1
fi

if ! jq -e 'type == "object" and (.key | type) == "string"' "$tmp_body" >/dev/null 2>&1; then
    echo "ERROR: unexpected GitLab API response for '${var_name}': $(cat "$tmp_body")" >&2
    exit 1
fi

if jq -e '.message' "$tmp_body" >/dev/null 2>&1; then
    echo "ERROR: GitLab API error for '${var_name}': $(jq -r '.message' "$tmp_body")" >&2
    exit 1
fi

jq -r '.value' "$tmp_body"
