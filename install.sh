#!/usr/bin/env bash
# hypr-shell Installer (Platzhalter – der vollständige Installer folgt in Gruppe 1)
set -euo pipefail

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --yes) ;;
        -h|--help) echo "Aufruf: ./install.sh [--yes] [--dry-run]"; exit 0 ;;
        *) echo "Unbekannte Option: $arg" >&2; exit 2 ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    echo "Bitte nicht als root starten." >&2
    exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Probelauf: es gibt noch nichts zu installieren."
else
    echo "Es gibt noch nichts zu installieren."
fi
