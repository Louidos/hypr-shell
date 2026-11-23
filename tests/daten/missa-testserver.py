#!/usr/bin/env python3
"""Lokaler Testserver für hypr-shell – spricht wie Missa-Core (OpenAI-Chat-Format, /api/…,
Geräte-Anschluss v1, CalDAV und Sensor), aber nur mit Beispielantworten und nur auf 127.0.0.1.
Nie gegen einen echten Server testen.

  missa-testserver.py PORT PROTOKOLLDATEI

API-Schlüssel "test-key", Geräte-Token "device-token" (Gerät "testgeraet"), CalDAV "kal"/"kal-pw".
Steuerung für Tests: POST /test/auftrag {werkzeug, argumente}, /test/meldung {…}, /test/abbruch {id},
/test/trennen; GET /test/ergebnisse, /test/anmeldungen.
"""
import json, sys, time, threading, uuid, base64
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

PORT = int(sys.argv[1])
LOG = sys.argv[2]
KEY, DEVICE = "test-key", "device-token"
lock = threading.Lock()
queue = []            # Ereignisse für den Geräte-Stream: (event, data)
results = []          # Ergebnisse vom Gerät
anmeldungen = []
stream_gen = [0]      # erhöht sich bei /test/trennen → offene Streams enden


def log(eintrag):
    with lock, open(LOG, "a") as f:
        f.write(json.dumps(eintrag, ensure_ascii=False) + "\n")


class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def send_json(self, code, obj, extra=None):
        b = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(b)

    def fehler(self, code, msg, c):
        self.send_json(code, {"error": {"message": msg, "type": "fehler", "code": c}})

    def auth(self, token):
        h = self.headers.get("Authorization", "")
        if h == "Bearer gesperrt":
            self.fehler(429, "Zu viele Fehlversuche – 15 Minuten warten.", "zu_viele_fehlversuche")
            return False
        if h != "Bearer " + token:
            self.fehler(401, "Fehlender oder ungültiger API-Schlüssel (Authorization: Bearer …)", "nicht_angemeldet")
            return False
        return True

    def body(self):
        n = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(n) if n else b""
        try:
            return json.loads(raw or b"{}")
        except ValueError:
            return {}

    # ------------------------------------------------------------------ GET
    def do_GET(self):
        p = self.path.split("?")[0]
        if p == "/health":
            return self.send_json(200, {"status": "ok", "version": "test", "llama": "ok", "charakter": "ok"})
        if p == "/sensor.json":
            return self.send_json(200, {"luft": {"co2": 1234, "pm25": 8.5}, "zeit": "2026-11-23T10:00:00"})
        if p == "/test/ergebnisse":
            return self.send_json(200, results)
        if p == "/test/anmeldungen":
            return self.send_json(200, anmeldungen)
        if p == "/api/geraete/auftraege":
            return self.stream()
        if not self.auth(KEY):
            return
        log({"get": p})
        daten = {
            "/api/lagebild": {"zeit": "2026-11-23T14:05:00+01:00", "text": "### Erinnerungen\n- Zahnarzt anrufen\n\n### Server\nAlles ruhig.",
                              "quellen": [{"name": "Erinnerungen", "status": "ok", "fremd": False}]},
            "/api/erinnerungen": {"anzahl": 2, "erinnerungen": [
                {"id": 1, "text": "Training", "faellig": "2026-11-24T06:30:00+01:00", "wiederholung_text": "jeden Mittwoch", "status": "offen"},
                {"id": 2, "text": "Zahnarzt anrufen", "faellig": "2026-11-24T09:00:00+01:00", "wiederholung_text": None, "status": "offen"}]},
            "/api/homelab": {"proxmox": True, "stand": "2026-11-23T09:00:00+01:00", "vms": [
                {"vmid": 110, "name": "rp01", "typ": "lxc", "node": "pve", "status": "running", "cpus": 1, "ram_mb": 512, "disk_gb": 8, "ips": ["10.0.70.10"]},
                {"vmid": 120, "name": "ai01", "typ": "qemu", "node": "pve", "status": "running", "cpus": 8, "ram_mb": 32768, "disk_gb": 200, "ips": ["10.0.70.20"]},
                {"vmid": 130, "name": "test01", "typ": "qemu", "node": "pve", "status": "stopped", "cpus": 2, "ram_mb": 2048, "disk_gb": 32, "ips": []}]},
            "/api/server": {"monitoring": True, "gemessen": "2026-11-23T14:07:00+01:00", "werte": [
                {"ziel": "ai01", "metrik": "cpu", "wert": 42.0, "einheit": "%"}, {"ziel": "ai01", "metrik": "ram", "wert": 61.0, "einheit": "%"}],
                "erreichbarkeit": [{"domain": "cloud.example.org", "status": "ok"}, {"domain": "git.example.org", "status": "fehler", "problem": "HTTP 502"}]},
            "/api/container": {"ssh": True, "hosts": {"wb01": {"stand": "2026-11-23T14:05:00+01:00", "container": [
                {"host": "wb01", "name": "nextcloud", "zustand": "running", "status": "Up 3 hours (healthy)", "gesundheit": "healthy"},
                {"host": "wb01", "name": "redis", "zustand": "exited", "status": "Exited (1)", "gesundheit": ""}]}}},
            "/api/alarme": {"anzahl": 1, "aktiv": ["ai01: CPU über 90 % seit 14:02 Uhr (notfall)"], "alarme": [
                {"id": 3, "zeit": "2026-11-23T14:07:00+01:00", "stufe": "notfall", "titel": "ai01: CPU über 90 %", "text": "aktuell 95 %"}]},
        }
        if p in daten:
            return self.send_json(200, daten[p])
        self.fehler(404, "Unbekannter Endpunkt", "nicht_gefunden")

    # ------------------------------------------------------------------ REPORT (CalDAV)
    def do_REPORT(self):
        h = self.headers.get("Authorization", "")
        if h != "Basic " + base64.b64encode(b"kal:kal-pw").decode():
            self.send_response(401); self.send_header("Content-Length", "0"); self.end_headers(); return
        self.rfile.read(int(self.headers.get("Content-Length", "0") or 0))
        log({"caldav": self.path})
        ev = lambda uid, start, summary: ("BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:%s\r\nDTSTART:%s\r\nSUMMARY:%s\r\nEND:VEVENT\r\nEND:VCALENDAR" % (uid, start, summary))
        jetzt = time.gmtime(time.time() + 86400)
        tag = time.strftime("%Y%m%d", jetzt)
        items = [ev("a", tag + "T090000Z", "Zahnarzt"), ev("b", tag + "T140000Z", "Projekt-Besprechung"),
                 ev("c", time.strftime("%Y%m%d", time.gmtime(time.time() + 3 * 86400)), "Geburtstag Anna")]
        xml = '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">' + "".join(
            "<d:response><d:href>/cal/%d.ics</d:href><d:propstat><d:prop><c:calendar-data>%s</c:calendar-data></d:prop></d:propstat></d:response>" % (i, x)
            for i, x in enumerate(items)) + "</d:multistatus>"
        b = xml.encode()
        self.send_response(207); self.send_header("Content-Type", "application/xml"); self.send_header("Content-Length", str(len(b))); self.end_headers()
        self.wfile.write(b)

    # ------------------------------------------------------------------ POST
    def do_POST(self):
        p = self.path.split("?")[0]
        if p.startswith("/test/"):
            b = self.body()
            with lock:
                if p == "/test/auftrag":
                    i = str(uuid.uuid4())
                    queue.append(("auftrag", {"id": i, "werkzeug": b["werkzeug"], "argumente": b.get("argumente", {}), "frist_s": b.get("frist_s", 60)}))
                    return self.send_json(200, {"id": i})
                if p == "/test/meldung":
                    queue.append(("meldung", b)); return self.send_json(200, {"ok": True})
                if p == "/test/abbruch":
                    queue.append(("abbruch", b)); return self.send_json(200, {"ok": True})
                if p == "/test/trennen":
                    stream_gen[0] += 1; return self.send_json(200, {"ok": True})
            return self.send_json(404, {})
        if p == "/api/geraete/anmelden":
            if not self.auth(DEVICE):
                return
            b = self.body()
            if b.get("protokoll") != 1 or b.get("geraet") != "testgeraet":
                return self.fehler(400, "geraet passt nicht zum Token", "ungueltige_anfrage")
            namen = [w["name"] for w in b.get("werkzeuge", [])]
            with lock:
                anmeldungen.append(b)
            return self.send_json(200, {"ok": True, "geraet": "testgeraet", "angenommen": namen, "abgelehnt": []})
        if p == "/api/geraete/ergebnis":
            if not self.auth(DEVICE):
                return
            b = self.body()
            with lock:
                if any(r.get("id") == b.get("id") for r in results):
                    return self.fehler(409, "schon erledigt", "doppelt")
                results.append(b)
            return self.send_json(200, {"ok": True})
        if p == "/v1/chat/completions":
            return self.chat()
        self.fehler(404, "Unbekannter Endpunkt", "nicht_gefunden")

    def chat(self):
        if not self.auth(KEY):
            return
        b = self.body()
        msgs = b.get("messages", [])
        frage = next((m.get("content", "") for m in reversed(msgs) if m.get("role") == "user"), "")
        log({"chat": frage, "anzahl": len(msgs), "session": self.headers.get("X-Missa-Session"),
             "modus": self.headers.get("X-Missa-Modus"), "stream": b.get("stream"), "model": b.get("model")})
        if "modellfehler" in frage:
            return self.fehler(502, "Das Sprachmodell ist nicht erreichbar (llama-server läuft nicht).", "modell_nicht_erreichbar")
        if "rückfrage" in frage.lower():
            antwort = "Soll ich den Termin **Zahnarzt** wirklich löschen?"
        else:
            antwort = "Hallo! Morgen hast du um 9:00 den **Zahnarzt**. Danach ist frei."
        if not b.get("stream"):
            return self.send_json(200, {"choices": [{"index": 0, "message": {"role": "assistant", "content": antwort}, "finish_reason": "stop"}]})
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        def chunk(d):
            self.wfile.write(("data: " + json.dumps(d, ensure_ascii=False) + "\n\n").encode()); self.wfile.flush()
        try:
            chunk({"choices": [{"index": 0, "delta": {"role": "assistant", "content": ""}, "finish_reason": None}]})
            for i, wort in enumerate(antwort.split(" ")):
                chunk({"choices": [{"index": 0, "delta": {"content": wort + (" " if i < len(antwort.split(" ")) - 1 else "")}, "finish_reason": None}]})
                time.sleep(4 if ("langsam" in frage and i == 1) else 0.15)
            chunk({"choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}]})
            self.wfile.write(b"data: [DONE]\n\n"); self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            log({"abgebrochen": frage})
        self.close_connection = True

    def stream(self):
        if not self.auth(DEVICE):
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        gen = stream_gen[0]
        try:
            self.wfile.write(b": verbunden\n\n"); self.wfile.flush()
            letzter = time.time()
            while gen == stream_gen[0]:
                ev = None
                with lock:
                    if queue:
                        ev = queue.pop(0)
                if ev:
                    self.wfile.write(("event: %s\ndata: %s\n\n" % (ev[0], json.dumps(ev[1], ensure_ascii=False))).encode()); self.wfile.flush()
                elif time.time() - letzter > 2:
                    self.wfile.write(b": ping\n\n"); self.wfile.flush(); letzter = time.time()
                time.sleep(0.05)
        except (BrokenPipeError, ConnectionResetError):
            pass
        self.close_connection = True


ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
