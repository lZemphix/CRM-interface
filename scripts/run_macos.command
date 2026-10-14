#!/bin/bash
set -euo pipefail
bundle_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
api_url="${1:-${CRM_API_URL:-http://127.0.0.1:8000}}"
# Quit an already-running CRM before launching with a different API endpoint.
exec open "$bundle_dir/CRM-interface.app" --args "--api-url=$api_url"
