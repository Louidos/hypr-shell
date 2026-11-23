#!/usr/bin/env bash
# Prüft Ordner und Schalter der Anbindungen mit einem lokalen WebDAV-Testserver (rclone serve webdav,
# nie ein echter Server): Standard alles aus (kein Ordner, kein Lesezeichen, kein Dienst); Nextcloud
# einschalten, Datei lesen und anlegen (mit FUSE wirklich eingehängt, sonst nur der Zugang), ausschalten
# räumt auf und lässt die Zugangsdaten stehen; fremde Lesezeichen bleiben; ~/Missa nur eingeschaltet;
# fehlendes rclone, falsches Passwort, Server nicht erreichbar; nirgends ein Passwort.
# shellcheck disable=SC2016,SC2034,SC2088,SC2329
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"
command -v jq >/dev/null || { echo "Hinweis: jq fehlt, übersprungen."; exit 0; }

T="$(mktemp -d)"
pids=()
aufraeumen() {
    local p
    fusermount3 -uz "$T/home/Nextcloud" 2>/dev/null || true
    for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
    pkill -f "rclone mount :webdav: $T" 2>/dev/null || true
    rm -rf "$T"
}
trap aufraeumen EXIT
export HOME="$T/home" HYPR_SHELL_NO_SYSTEMD=1
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CONFIG_HOME
mkdir -p "$HOME/.local/share/hypr-shell" "$HOME/.config/gtk-3.0" "$T/server/Dokumente"
EFF="$HOME/.local/share/hypr-shell/settings.effective.json"
fehler=0
pruefe() { if eval "$1"; then echo "  ok: $2"; else echo "  FEHLER: $2"; fehler=1; fi; }
mnt() { "$REPO/bin/shell-mount" "$@"; }
st() { mnt nextcloud status | jq -r "$1"; }

echo "== Standard: alles aus"
printf 'file:///home/fremd/Projekte Projekte\n' > "$HOME/.config/gtk-3.0/bookmarks"
"$REPO/bin/shell-apply" --effective > "$EFF" 2>/dev/null || echo '{}' > "$EFF"
pruefe '[ "$(jq -c "[.nextcloud.enabled, .missa.enabled, .missa.agent_enabled, .missa.voice_enabled, .lab.enabled, .calendar.enabled, .sensor.enabled, .games.custom_enabled]" "$EFF")" = "[false,false,false,false,false,false,false,false]" ]' "alle persönlichen Anbindungen sind aus"
mnt sync
pruefe '[ ! -e "$HOME/Nextcloud" ] && [ ! -e "$HOME/Missa" ] && [ "$(cat "$HOME/.config/gtk-3.0/bookmarks")" = "file:///home/fremd/Projekte Projekte" ]' "kein Ordner, kein Lesezeichen"
pruefe '[ "$(mnt status | jq -c "[.nextcloud.state, .missa.state]")" = "[\"off\",\"off\"]" ]' "Status: aus"
pruefe '! grep -q "WantedBy" config/systemd/user/shell-mount-nextcloud.service && ! grep -rq "shell-mount-nextcloud" config/hypr/hyprland.lua' "Dienst wird nicht beim Anmelden gestartet (nur shell-mount startet ihn)"

echo "== Missa-Ordner"
jq '.missa.enabled = true' "$EFF" > "$EFF.n" && mv "$EFF.n" "$EFF"
mnt sync
pruefe '[ -d "$HOME/Missa/Eingang" ] && [ -d "$HOME/Missa/Ausgabe" ] && grep -qx "file://$HOME/Missa Missa" "$HOME/.config/gtk-3.0/bookmarks" && grep -qx "file://$HOME/Missa Missa" "$HOME/.config/gtk-4.0/bookmarks"' "eingeschaltet: ~/Missa mit Eingang und Ausgabe, Lesezeichen in GTK 3 und 4"
echo "Notiz" > "$HOME/Missa/Eingang/notiz.txt"
jq '.missa.enabled = false' "$EFF" > "$EFF.n" && mv "$EFF.n" "$EFF"
mnt sync
pruefe '[ -f "$HOME/Missa/Eingang/notiz.txt" ] && ! grep -q "Missa" "$HOME/.config/gtk-3.0/bookmarks" && grep -q "Projekte" "$HOME/.config/gtk-3.0/bookmarks"' "ausgeschaltet: Lesezeichen weg, Inhalte bleiben, fremde Lesezeichen unberührt"
rm "$HOME/Missa/Eingang/notiz.txt"; mnt sync
pruefe '[ ! -e "$HOME/Missa" ]' "leerer Missa-Ordner verschwindet"

echo "== Nextcloud ohne rclone"
mkdir -p "$T/nix"; for p in bash jq sed grep awk cat mkdir rmdir dirname readlink base64 tail head pkill sleep mktemp mv chmod touch; do ln -sf "$(command -v "$p")" "$T/nix/$p"; done
jq '.nextcloud.enabled = true | .nextcloud.url = "http://127.0.0.1:1" | .nextcloud.user = "alice"' "$EFF" > "$EFF.n" && mv "$EFF.n" "$EFF"
r="$(PATH="$T/nix" "$REPO/bin/shell-mount" nextcloud status)"
pruefe '[ "$(jq -r .state <<<"$r")" = missing ] && jq -e ".text | test(\"rclone\")" <<<"$r" >/dev/null && PATH="$T/nix" "$REPO/bin/shell-mount" nextcloud up' "Hinweis (rclone missing) mit Paketname, kein Fehler"

if ! command -v rclone >/dev/null 2>&1; then echo "Hinweis: rclone fehlt, Rest übersprungen."; exit "$fehler"; fi

echo "== Zugangsdaten"
pruefe '[ "$(st .state)" = setup ] && st .text | grep -q "app password"' "eingeschaltet ohne Passwort: kurze Anleitung statt Fehler"
printf 'geheim-123\n' | "$REPO/bin/shell-secrets" set NEXTCLOUD_APP_PASSWORD
pruefe '[ "$(stat -c %a "$HOME/.config/hypr-shell/secrets.env")" = 600 ] && ! grep -q "geheim-123" "$HOME/.config/hypr-shell/secrets.env"' "secrets.env mit Rechten 600"

echo "== Testserver"
port=$(( 20000 + RANDOM % 20000 ))
echo "Hallo aus der Cloud" > "$T/server/Dokumente/willkommen.txt"
rclone serve webdav "$T/server" --addr "127.0.0.1:$port" --baseurl /remote.php/dav/files/alice --user alice --pass geheim-123 >"$T/serve.log" 2>&1 &
pids+=("$!")
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$port/" && break; sleep 0.1; done
jq --arg u "http://127.0.0.1:$port" '.nextcloud.url = $u' "$EFF" > "$EFF.n" && mv "$EFF.n" "$EFF"
pruefe '[ "$(mnt nextcloud check | jq -r .state)" = ready ]' "Zugang zum Testserver"
printf 'falsch\n' | "$REPO/bin/shell-secrets" set NEXTCLOUD_APP_PASSWORD
pruefe '[ "$(mnt nextcloud check | jq -c "[.state, .text]")" = "[\"error\",\"Wrong user name or app password\"]" ]' "falsches Passwort: klare Meldung"
printf 'geheim-123\n' | "$REPO/bin/shell-secrets" set NEXTCLOUD_APP_PASSWORD
jq '.nextcloud.url = "http://127.0.0.1:1"' "$EFF" > "$EFF.n" && mv "$EFF.n" "$EFF"
pruefe '[ "$(mnt nextcloud check | jq -c "[.state, .text]")" = "[\"error\",\"Server not reachable\"]" ]' "Server nicht erreichbar: ruhige Meldung"
jq --arg u "http://127.0.0.1:$port" '.nextcloud.url = $u' "$EFF" > "$EFF.n" && mv "$EFF.n" "$EFF"

if [ -e /dev/fuse ] && command -v fusermount3 >/dev/null 2>&1 && [ -w /dev/fuse ]; then
    echo "== Einhängen (FUSE)"
    mnt nextcloud up
    for _ in $(seq 1 50); do grep -qs " $HOME/Nextcloud fuse" /proc/mounts && break; sleep 0.2; done
    pruefe 'grep -qs " $HOME/Nextcloud fuse" /proc/mounts && grep -qx "file://$HOME/Nextcloud Nextcloud" "$HOME/.config/gtk-3.0/bookmarks"' "~/Nextcloud eingehängt, Lesezeichen in der Seitenleiste"
    pruefe '[ "$(cat "$HOME/Nextcloud/Dokumente/willkommen.txt")" = "Hallo aus der Cloud" ]' "Datei vom Server lesen"
    echo "neu vom Laptop" > "$HOME/Nextcloud/Dokumente/neu.txt"; sync
    for _ in $(seq 1 40); do [ -f "$T/server/Dokumente/neu.txt" ] && break; sleep 0.5; done
    pruefe '[ "$(cat "$T/server/Dokumente/neu.txt" 2>/dev/null)" = "neu vom Laptop" ]' "Datei anlegen – sie liegt danach auf dem Testserver"
    pruefe '! ps -eo args | grep "rclone mount" | grep -q "geheim-123" && ! grep -rqs "geheim-123" "$HOME/.config/rclone" "$T/serve.log"' "Passwort nicht in der Prozessliste und in keiner rclone-Datei"
    jq '.nextcloud.enabled = false' "$EFF" > "$EFF.n" && mv "$EFF.n" "$EFF"
    mnt sync
    pruefe '! grep -qs " $HOME/Nextcloud fuse" /proc/mounts && [ ! -e "$HOME/Nextcloud" ] && ! grep -q "Nextcloud" "$HOME/.config/gtk-3.0/bookmarks" && "$REPO/bin/shell-secrets" has NEXTCLOUD_APP_PASSWORD' "ausschalten: ausgehängt, Lesezeichen weg, Zugangsdaten bleiben"
else
    echo "  Hinweis: kein FUSE hier – Einhängen nur mit FUSE prüfbar (lokal bzw. auf dem Rechner)"
fi

echo "== nirgends ein Passwort"
pruefe '! jq -r ".keys[] | .key" settings/schema.json | grep -iE "pass|secret|token|key\$" | grep -qv "^look.blur.passes\$"' "keine Zugangsdaten im Schema (also nie in settings.json)"
pruefe '! git -C "$REPO" grep -qiE "(password|passwort|token)[[:space:]]*[:=][[:space:]]*[\"'"'"'][^\"'"'"'$ ]{6,}" -- ":!tests" ":!docs" ":!*.md"' "git grep findet kein Passwort"
pruefe '[ "$(jq -c ".nextcloud.enabled, .missa.enabled, .lab.enabled" settings/anbindungen.example.json | tr "\n" ",")" = "true,true,true," ] && [ "$(jq -c ".nextcloud.enabled" settings/settings.example.json)" = false ]' "Beispielprofil mit allem an, Standarddatei mit allem aus"
exit "$fehler"
