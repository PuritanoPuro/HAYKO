# HAYKO Smartwatch

La prima implementazione compilabile e' in `zeppos/` ed e' progettata per
Amazfit Bip 5 (320 x 380, API_LEVEL 2.1). Riproduce il flusso approvato in Figma:

1. partita programmata piu' vicina all'orario corrente;
2. avvio manuale;
3. punteggio, cronometro e turno portiere;
4. squadra che segna, marcatore, assist e portiere;
5. conferma del gol.

I comandi sono creati con un identificatore stabile e inseriti nell'outbox prima
di essere inviati. La UI usa ancora uno snapshot dimostrativo: il relay verso
Supabase verra' collegato nel Side Service senza cambiare il flusso sul display.

## Bip 5 / Zepp OS

Il target usa esclusivamente API disponibili dal livello 2.1. Per compilarlo:

```sh
cd watch/zeppos
zeus build
```

Per provarlo sul dispositivo, dopo il login Zepp:

```sh
zeus preview
```

Nella Zepp App deve essere attiva la modalita sviluppatore. Il target comprende
entrambe le varianti Bip 5 (`8454400` e `8454401`).

## Contratto multipiattaforma

Il contratto in `zeppos/shared/protocol.js` e' indipendente dall'interfaccia e
costituisce la base per i client watchOS e Wear OS. I tre pacchetti resteranno
nativi per rispettare navigazione, connettivita e vincoli delle piattaforme.

## Specifica precedente

Questo percorso contiene la specifica smartwatch; non ci sono ancora app native
compilabili o bridge integrati nel mobile. Lo sviluppo delle tre integrazioni
può iniziare in parallelo dopo il gateway autenticato.

## UI comune
Home: punteggio confermato, stato connessione, ultimo aggiornamento, GOL.
GOL → squadra beneficiaria → marcatore → assist (anche nessuno) → portiere
avversario (anche non indicato) → riepilogo → conferma.
Autogol in selezione marcatore: lista squadra avversaria, assist disabilitato.
Indietro ritorna alla scelta precedente, Annulla elimina soltanto la bozza.
Un gol già confermato si annulla dal registro con comando `void_goal`.
Vibrazione di successo dopo ACK ufficiale, feedback diverso per bozza in coda.
Ogni schermata deve funzionare senza scorrimento orizzontale; lista nomi breve
con alias opzionale, target tattili grandi e supporto Digital Crown/rotary.

## watchOS
Target separato Xcode SwiftUI; DTO Codable corrispondente a command.schema.json.
WCSession per relay iPhone: sendMessage quando raggiungibile, transferUserInfo
per consegna differita. Outbox persistente prima di inviare; la sola coda
WatchConnectivity non sostituisce il registro degli ACK di dominio.
Snapshot latest tramite updateApplicationContext. Un canale raggiungibile
non implica server online. Mai interpretare il successo del trasporto come gol
confermato. Connessione HTTPS diretta è un'evoluzione dopo pairing sicuro.

## Wear OS
Modulo Kotlin/Compose for Wear OS. Data Layer MessageClient per comandi relay,
DataClient per snapshot; stesso package e firma sul telefono Android.
Outbox persistente locale e ACK di dominio; API HTTP comune quando si sceglie
modalità indipendente. Data Layer non è disponibile verso un iPhone: non
promettere compatibilità iOS per qualsiasi Galaxy Watch. Verificare modello,
abbinamento supportato e connettività prima di segnare un device supportato.

## Zepp OS / Bip 5
Mini Program JavaScript con Device App + Settings App + Side Service in Zepp.
Bip 5: API_LEVEL 2.1, display 320×380; non usare soltanto API introdotte in 3+.
Il Side Service comunica via HTTPS al gateway e restituisce ACK/snapshot al
Device App. Non assumere accesso diretto al Flutter companion o rete sul watch.
Settings App: codice pairing monouso; nessuna password personale sul watch.
PoC obbligatorio: timer e permanenza del servizio in background, storage
persistente, fetch autenticato, disconnessione Bluetooth, sospensione Zepp,
riapertura e replay outbox, comportamento iPhone/Android su dispositivi reali.

## Accettazione identica per i tre client
- Doppio invio dello stesso ID produce un gol.
- Due comandi con revisione uguale: uno accettato, altro da riconciliare.
- Cambio registratore: vecchio dispositivo non può aggiungere gol offline.
- Chiusura partita: bozze non inviate si mostrano come da risolvere.
- Riavvio dopo invio prima di ACK: ritrasmette stesso ID e stesso payload.
- Snapshot vecchio non sovrascrive una revisione più nuova.
- Viewer può consultare, non vede controlli di scrittura.
- Annullamento confermato compare sul mobile e su tutti i watch.

Fonti: https://developer.apple.com/documentation/watchconnectivity/wcsession
https://developer.android.com/training/wearables/data/overview
https://docs.zepp.com/docs/guides/architecture/arc/
https://docs.zepp.com/docs/reference/related-resources/device-list/
