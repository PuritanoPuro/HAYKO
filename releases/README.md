# Build HAYKO per i test

Gli artefatti installabili sono divisi per piattaforma e versione:

```text
releases/
  android/
    <versione Flutter>/
  ios/
    <versione Flutter>/
```

Le cartelle di versione possono contenere istruzioni, metadati e checksum. I binari `.apk` sono locali e non vengono salvati in Git.

La versione deriva dal campo `version` di `mobile/pubspec.yaml`. Prima di generare una nuova versione, aggiornare quel campo e creare una nuova cartella senza sovrascrivere gli artefatti precedenti.
