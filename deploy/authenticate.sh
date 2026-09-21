#!/usr/bin/env bash
# One-time device-code authentication. Tokens persist in the bind-mounted
# cache files, so you only do this once per host.
# Usage: ./deploy/authenticate.sh [--read-only]
set -euo pipefail
exec "$(dirname "${BASH_SOURCE[0]}")/run.sh" authenticate "$@"
