# Supabase

Questa cartella contiene gli script SQL correnti e i template email. Nessun comando del repository li distribuisce automaticamente.

## Progetto nuovo

Nel SQL Editor di un progetto Supabase nuovo eseguire in ordine:

1. `migrations/20261016_account_v1.sql`: schema, ruoli, RPC, profili e gestione account. Lo script contiene una transazione e rifiuta l'esecuzione se trova già le tabelle dell'app.
2. `migrations/20261017_short_invites.sql`: codici invito brevi e protezioni sui tentativi.

Non eseguire prima gli SQL di backend/legacy: sono versioni storiche già incorporate nell'installazione di base. Su un progetto esistente verificare quali script sono già stati applicati; non rieseguire l'installazione completa.

Configurare provider email, URL di reindirizzamento e template nel pannello Supabase, seguendo i flussi implementati in mobile/lib/features/account. I file templates contengono i template di conferma e recupero password. Verificare il ciclo completo su un dispositivo prima di distribuire l'app.

La configurazione client si trova in mobile/cloud-config.local.json, escluso da Git. Gli script non sono stati applicati al progetto remoto durante la riorganizzazione del repository.
