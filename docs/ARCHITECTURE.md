# Architettura

## Applicazione Flutter

- `main.dart`: inizializzazione Flutter, licenze, Supabase e link invito.
- `app.dart`: tema, MaterialApp e accesso tramite AccountGate.
- `core/domain/`: modelli, regole delle partite, statistiche e competizioni.
- `core/config/`: configurazione fornita tramite dart-define.
- `core/services/`: integrazione Supabase e notifiche locali.
- `features/account/`: autenticazione, profilo, preferenze, inviti e cache per account.
- `features/home/`: schermata principale e navigazione iniziale.
- `features/leagues/`: creazione, impostazioni e dettaglio lega.
- `features/matches/`: formazione, partita, gol e modifica squadre.
- `features/competitions/`: calendari, tornei e rose.
- `features/statistics/` e `features/teams/`: statistiche e squadre salvate.
- `design_system/`: colori, tema e componenti della home HAYKO.
- `shared/`: presentazione, personalizzazione e utilità UI comuni.

Le schermate precedentemente raccolte in main.dart sono file distinti. Gli import usano percorsi package espliciti. Il codice Dart e i test sono formattati con dart format.

## Dati

Le schermate modificano il modello League e invocano Cloud.save. LeagueStore conserva snapshot e operazioni ordinate in SharedPreferences, separati per account. La sincronizzazione invia le operazioni via RPC Supabase con controllo della revisione. Il backend SQL applica ruoli e regole di integrità.

Il motore Python in backend è un riferimento storico verificabile, non un servizio necessario all'avvio dell'app. L'installazione Supabase corrente è autonoma rispetto agli SQL in backend/legacy.

## Evoluzione

La riorganizzazione conserva le API e il comportamento preesistenti. Cloud include ancora alcuni flussi UI sociali: una successiva separazione completa fra repository dati e presentazione richiederà test dedicati. I problemi funzionali già identificati sono descritti in KNOWN_ISSUES.md.
