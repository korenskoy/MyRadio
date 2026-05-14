#!/usr/bin/env bash
#
# Add or update a key in MyRadio/Localizable.xcstrings.
#
# Usage:
#   ./scripts/add-l10n.sh KEY [--comment TEXT] [--LOCALE VALUE]...
#
# Example:
#   ./scripts/add-l10n.sh "Quit MyRadio?" \
#     --comment "Confirm-quit alert" \
#     --ru "Выйти из MyRadio?" \
#     --de "MyRadio beenden?"
#
# KEY is also used as the English source unless --en "..." is passed.
# Locales not listed are simply omitted; rerun the script to add more.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$DIR/_l10n.py" add "$@"
