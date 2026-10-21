#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mobile_dir="$project_root/mobile"
config_file="$mobile_dir/cloud-config.local.json"

if [[ "$platform" != "android" && "$platform" != "ios" ]]; then
  echo "Uso: $0 android|ios" >&2
  exit 64
fi

python3 - "$config_file" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
if not path.is_file():
    raise SystemExit("Configurazione cloud assente: mobile/cloud-config.local.json")

data = json.loads(path.read_text())
url = str(data.get("SUPABASE_URL", "")).strip()
key = str(data.get("SUPABASE_PUBLISHABLE_KEY") or data.get("SUPABASE_ANON_KEY") or "").strip()
if not url.startswith("https://") or ".supabase.co" not in url or not key:
    raise SystemExit("Configurazione Supabase incompleta o non valida")
if "INSERISCI" in url.upper() or "INSERISCI" in key.upper():
    raise SystemExit("La configurazione contiene ancora valori di esempio")
PY

cd "$mobile_dir"
if [[ "$platform" == "android" ]]; then
  flutter build apk --release --dart-define-from-file="$config_file"
else
  flutter build ios --release --dart-define-from-file="$config_file"
fi
