#!/usr/bin/env bash
# Prüft Syntax und Stil aller Skripte und Konfigurationsdateien.
# Fehlt ein Prüfprogramm, wird der Teil übersprungen und das gemeldet.
# Braucht shellcheck ab 0.10 (die CI nutzt 0.11); ältere Versionen melden SC2317/SC2015 auch dort,
# wo der Code in Ordnung ist.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fehler=0
melde() { echo "FEHLER: $*" >&2; fehler=1; }

# Shell-Skripte: install.sh, alles in bin/ mit Shell-Kopfzeile, tests/*.sh
mapfile -t skripte < <(
    echo install.sh
    for f in bin/* tests/*.sh settings/completions/*.bash; do
        [ -f "$f" ] || continue
        case "$f" in *.sh|*.bash) echo "$f"; continue ;; esac
        head -n1 "$f" | grep -qE '^#!.*(ba)?sh' && echo "$f"
    done
)
for f in "${skripte[@]}"; do
    bash -n "$f" || melde "Bash-Syntax: $f"
done
if command -v shellcheck >/dev/null; then
    sc_version="$(shellcheck --version | sed -n 's/^version: //p')"
    echo "shellcheck ${sc_version:-?}"
    if [ "$(printf '%s\n' "${sc_version:-0}" 0.10 | sort -V | head -n1)" != 0.10 ]; then
        echo "Hinweis: shellcheck ${sc_version:-?} ist älter als 0.10 – Meldungen SC2317/SC2015 können Fehlalarme sein (CI: 0.11)."
    fi
    shellcheck -x "${skripte[@]}" || melde "shellcheck"
else
    echo "Hinweis: shellcheck fehlt, übersprungen."
fi

# Python (Missa-Agent, Testserver)
if command -v python3 >/dev/null; then
    for f in bin/* tests/daten/*; do
        if [ ! -f "$f" ] || ! head -n1 "$f" | grep -q python; then continue; fi
        python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$f" || melde "Python: $f"
    done
fi

# JSON
if command -v jq >/dev/null; then
    while IFS= read -r -d '' f; do
        jq empty "$f" >/dev/null 2>&1 || melde "JSON: $f"
    done < <(find config settings -name '*.json' -print0 2>/dev/null)
fi

# Lua
luac=$(command -v luac5.4 || command -v luac || true)
if [ -n "$luac" ]; then
    while IFS= read -r -d '' f; do
        "$luac" -p "$f" || melde "Lua: $f"
    done < <(find config -name '*.lua' -print0 2>/dev/null)
else
    echo "Hinweis: luac fehlt, Lua übersprungen."
fi

# QML: Eigenschaften dürfen nicht mit "on" + Grossbuchstabe beginnen (QML hält sie für Signal-Handler)
if grep -rnE 'property +[A-Za-z0-9_.<>]+ +on[A-Z]' --include='*.qml' quickshell 2>/dev/null; then
    melde "QML-Eigenschaft beginnt mit on + Grossbuchstabe"
fi

# QML (nur Syntax; Quickshell-Module kennt qmlformat nicht, das ist egal)
qmlformat=$(command -v qmlformat || command -v qmlformat6 || ls /usr/lib/qt6/bin/qmlformat 2>/dev/null || true)
if [ -n "$qmlformat" ]; then
    while IFS= read -r -d '' f; do
        "$qmlformat" "$f" >/dev/null 2>&1 || { "$qmlformat" "$f" >/dev/null; melde "QML: $f"; }
    done < <(find quickshell sddm tests/daten -name '*.qml' -print0 2>/dev/null)
else
    echo "Hinweis: qmlformat fehlt, QML übersprungen."
fi

[ "$fehler" -eq 0 ] && echo "Alle Prüfungen bestanden."
exit "$fehler"
