#!/usr/bin/env bash
#
# Remove a key (or a single locale) from MyRadio/Localizable.xcstrings.
#
# Usage:
#   ./scripts/remove-l10n.sh KEY                  # remove the whole entry
#   ./scripts/remove-l10n.sh KEY --locale ru      # drop just the Russian translation
#
# The source locale (en) can never be removed individually — drop the key
# itself if it's no longer needed.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$DIR/_l10n.py" remove "$@"
