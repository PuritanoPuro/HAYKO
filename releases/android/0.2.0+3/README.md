# HAYKO Android 0.2.0+3

## Artefatto

```text
HAYKO-0.2.0-build3-android-internal.apk
```

- Version name: `0.2.0`
- Version code: `3`
- Package corrente: `com.example.calcetto_mvp`
- Min SDK: 24
- Target SDK: 36
- Tipo: release ottimizzata per test interni
- Firma: Android Debug
- Correzione principale: le azioni attendono la sincronizzazione già in corso invece di mostrare prematuramente `Completa prima la sincronizzazione`
- Commit sorgente: `648671807b5a74ac363af628cad4f42615b2e171`

Installazione con Android Platform Tools:

```sh
adb install -r HAYKO-0.2.0-build3-android-internal.apk
```

Verificare l’integrità confrontando il file con `SHA256SUMS.txt`:

```sh
shasum -a 256 -c SHA256SUMS.txt
```
