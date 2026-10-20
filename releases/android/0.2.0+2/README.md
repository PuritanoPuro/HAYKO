# HAYKO Android 0.2.0+2

## Artefatto

```text
HAYKO-0.2.0-build2-android-internal.apk
```

- Version name: `0.2.0`
- Version code: `2`
- Package corrente: `com.example.calcetto_mvp`
- Min SDK: 24
- Target SDK: 36
- Tipo: release ottimizzata per test interni
- Firma: Android Debug, APK Signature Scheme v2 verificato
- Configurazione cloud: inclusa tramite `cloud-config.local.json`
- Commit sorgente: `fbb3630c6620257f2650253042c059694e33956f`

Questa build può essere installata direttamente su un dispositivo Android abilitato all’installazione da sorgenti esterne. Non è una build Play Store: prima della distribuzione pubblica occorrono application ID definitivo e firma release privata.

Installazione con Android Platform Tools:

```sh
adb install -r HAYKO-0.2.0-build2-android-internal.apk
```

Verificare l’integrità confrontando il file con `SHA256SUMS.txt`:

```sh
shasum -a 256 -c SHA256SUMS.txt
```
