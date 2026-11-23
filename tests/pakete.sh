#!/usr/bin/env bash
# Prüft, dass jedes Paket aus install.sh (oder ein Ausweichname) in den Arch-Paketquellen
# oder im AUR existiert. Läuft nur auf Arch-Systemen (in der CI im archlinux-Container).
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

if ! command -v pacman >/dev/null 2>&1; then
    echo "Hinweis: kein pacman, Paketprüfung übersprungen."
    exit 0
fi

# Listen aus install.sh lesen, ohne den Installer auszuführen
eval "$(sed -n '/^PAKETE=(/,/^)/p; /^declare -A ALTERNATIVEN=(/,/^)/p' install.sh)"

aur_gibt_es() {
    command -v curl >/dev/null 2>&1 || return 1
    curl -fsS "https://aur.archlinux.org/rpc/v5/info?arg[]=$1" | grep -q '"resultcount":[1-9]'
}

fehler=0
for p in "${PAKETE[@]}"; do
    gefunden=""
    # shellcheck disable=SC2086
    for k in "$p" ${ALTERNATIVEN[$p]:-}; do
        if pacman -Si "$k" >/dev/null 2>&1; then gefunden="$k (repo)"; break; fi
        if aur_gibt_es "$k"; then gefunden="$k (AUR)"; break; fi
    done
    if [ -n "$gefunden" ]; then echo "  ok: $p -> $gefunden"; else echo "  FEHLT: $p"; fehler=1; fi
done
exit "$fehler"
