"""Genera host Android/iOS senza perdere i sorgenti del pacchetto iniziale."""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1] / 'mobile'
if not shutil.which('flutter'):
    raise SystemExit('Flutter non trovato. Installarlo e aggiungerlo al PATH prima del bootstrap.')
if (root / 'ios').exists() or (root / 'android').exists():
    raise SystemExit('Host già presenti: non serve bootstrap; usa flutter pub get.')
with tempfile.TemporaryDirectory() as tmp:
    backup = Path(tmp)
    for name in ('lib', 'test', 'pubspec.yaml'):
        source = root / name
        if source.is_dir():
            shutil.copytree(source, backup / name)
        else:
            shutil.copy2(source, backup / name)
    try:
        subprocess.run(['flutter', 'create', '--platforms=ios,android', '--project-name',
                        'calcetto_mvp', '--no-pub', '.'], cwd=root, check=True)
    finally:
        for name in ('lib', 'test', 'pubspec.yaml'):
            source, target = backup / name, root / name
            if source.is_dir():
                if target.exists():
                    shutil.rmtree(target)
                shutil.copytree(source, target)
            else:
                shutil.copy2(source, target)
print('Host generati. Ora: cd mobile && flutter pub get && flutter analyze && flutter test')
