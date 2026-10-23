#!/usr/bin/env bash
#
# Runs one `run:` block from template/.github/workflows/ci.yml, looked up by
# job id and step name, in the current directory.
#
# The self-test uses this so it exercises the exact commands people copy,
# instead of a second copy of them that could drift.
#
# Usage: run-template-step.sh <job-id> "<step name>"

set -euo pipefail

workflow="$(cd "$(dirname "$0")/../.." && pwd)/template/.github/workflows/ci.yml"
job="$1"
step="$2"

script="$(yq -e ".jobs.${job}.steps[] | select(.name == \"${step}\") | .run" "$workflow")"

echo "::group::template ${job} / ${step}"
echo "$script"
echo "::endgroup::"

bash -eo pipefail -c "$script"
