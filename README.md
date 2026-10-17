# HAYKO

App Flutter per organizzare leghe di calcetto, partite e competizioni, registrare gol e assist e consultare statistiche. Account, inviti e condivisione usano Supabase. Le modifiche alle leghe già caricate vengono salvate sul dispositivo e accodate per la sincronizzazione.

## Struttura

- `mobile/`: app Flutter per Android e iOS, asset e test.
- `supabase/`: installazione SQL corrente e template email.
- `backend/`: motore Python di riferimento e test; non è il server usato dall'app.
- `backend/legacy/`: SQL storico, separato dall'installazione corrente.
- `contracts/`: schema storico dei comandi.
- `docs/`: architettura, sviluppo e limiti conosciuti.
- `docs/history/`: documentazione e strumenti delle versioni precedenti.
- `watch/`: note sul supporto smartwatch, non ancora implementato.

## Avvio

Versione verificata: Flutter **3.47.7**, Dart **3.13.5**. Il nome interno del package resta `calcetto_mvp` per conservare la compatibilità; il nome dell'app è HAYKO.

```sh
cd mobile
flutter pub get
cp cloud-config.example.json cloud-config.local.json
# Compilare cloud-config.local.json con URL e chiave pubblica del proprio progetto.
flutter run --dart-define-from-file=cloud-config.local.json
```

Usare soltanto la chiave Supabase publishable/anon sul client, mai `service_role` o chiavi segrete. La configurazione locale è esclusa da Git. La build senza configurazione mostra la schermata di connessione non disponibile.

Per predisporre il backend consultare [supabase/README.md](supabase/README.md).

## Verifiche

```sh
cd mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
cd ..
python3 -m unittest discover -s backend -p 'test_*.py'
```

GitHub Actions esegue questi controlli a ogni push e pull request. Non esegue installazioni SQL o deploy.

[Architettura](docs/ARCHITECTURE.md) · [Sviluppo](docs/DEVELOPMENT.md) · [Limiti conosciuti](docs/KNOWN_ISSUES.md)
