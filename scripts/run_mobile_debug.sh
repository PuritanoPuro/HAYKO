#!/usr/bin/env bash
set -euo pipefail

device_id="${1:-}"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mobile_dir="$project_root/mobile"
config_file="$mobile_dir/cloud-config.local.json"

if [[ -z "$device_id" ]]; then
  echo "Uso: $0 <device-id>" >&2
  echo "Dispositivi disponibili:" >&2
  (cd "$mobile_dir" && flutter devices) >&2
  exit 64
fi

python3 - "$config_file" <<'PY'
import json
import pathlib
import sys
import urllib.error
import urllib.request

path = pathlib.Path(sys.argv[1])
if not path.is_file():
    raise SystemExit("Configurazione cloud assente: mobile/cloud-config.local.json")

data = json.loads(path.read_text())
url = str(data.get("SUPABASE_URL", "")).strip().rstrip("/")
key = str(data.get("SUPABASE_PUBLISHABLE_KEY") or data.get("SUPABASE_ANON_KEY") or "").strip()
if not url.startswith("https://") or ".supabase.co" not in url or not key:
    raise SystemExit("Configurazione Supabase incompleta o non valida")
if "INSERISCI" in url.upper() or "INSERISCI" in key.upper():
    raise SystemExit("La configurazione Supabase contiene ancora valori di esempio")

request = urllib.request.Request(
    f"{url}/auth/v1/health",
    headers={"apikey": key},
)
try:
    with urllib.request.urlopen(request, timeout=12) as response:
        if response.status != 200:
            raise SystemExit(f"Supabase non disponibile: HTTP {response.status}")
except (urllib.error.URLError, TimeoutError) as error:
    raise SystemExit(f"Impossibile raggiungere Supabase: {error}") from error

print("Preflight Supabase superato")
PY

cd "$mobile_dir"
exec flutter run \
  -d "$device_id" \
  --no-resident \
  --dart-define-from-file="$config_file"
