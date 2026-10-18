# Supabase

Questa cartella contiene gli script SQL correnti e i template email. Nessun comando del repository li distribuisce automaticamente.

## Progetto nuovo

Nel SQL Editor di un progetto Supabase nuovo eseguire in ordine:

1. `migrations/20261016_account_v1.sql`: schema, ruoli, RPC, profili e gestione account. Lo script contiene una transazione e rifiuta l'esecuzione se trova già le tabelle dell'app.
2. `migrations/20261017_short_invites.sql`: codici invito brevi e protezioni sui tentativi.
3. `migrations/20261018_json_containment_precedence.sql`: parentesi negli operatori JSON dei validatori. È incrementale e accetta anche la correzione manuale già applicata.
4. `migrations/20261019_invite_preview.sql`: anteprima del nome della lega per i link invito. È incrementale e accetta soltanto i token lunghi usati dai link.

Non eseguire prima gli SQL di backend/legacy: sono versioni storiche già incorporate nell'installazione di base. Su un progetto esistente verificare quali script sono già stati applicati; non rieseguire l'installazione completa.

Configurare provider email, URL di reindirizzamento e template nel pannello Supabase, seguendo i flussi implementati in mobile/lib/features/account. I file templates contengono i template di conferma e recupero password. Verificare il ciclo completo su un dispositivo prima di distribuire l'app.

La configurazione client si trova in mobile/cloud-config.local.json, escluso da Git. Gli script non sono stati applicati al progetto remoto durante la riorganizzazione del repository.

## Aggiornare un progetto già installato

Per il problema `operator does not exist: boolean -> unknown`, eseguire soltanto
`migrations/20261018_json_containment_precedence.sql` nel SQL Editor. Non rieseguire
il bootstrap. La patch legge le due funzioni esistenti e corregge esclusivamente
le cinque espressioni note, conservando permessi, proprietà e impostazioni.
Se una funzione manca o ha una definizione inattesa, la transazione si interrompe
senza applicare modifiche parziali: analizzare l'errore prima di procedere.
Non modifica tabelle, revisioni, cache o operazioni offline.

Per mostrare il nome della lega nella schermata aperta da un link invito, eseguire
`migrations/20261019_invite_preview.sql` nel SQL Editor. La funzione è disponibile
solo agli account autenticati e non accetta i codici brevi inseriti manualmente.

## Test isolati dei validatori

Con Node.js e pnpm disponibili:

```sh
cd supabase/tests
pnpm install --frozen-lockfile
pnpm test
```

PGlite esegue PostgreSQL in memoria con un piccolo schema auth simulato. I test
riproducono il problema prima della patch, verificano rotazioni, preset,
campionato e torneo dopo la patch, i rifiuti di dati non validi, le revisioni,
il controllo esclusivo del creatore e la conservazione di ACL e dati.
Controllano anche la riesecuzione e il rollback su definizioni inattese.
Non collegano né modificano il progetto Supabase reale.
