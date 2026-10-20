# HAYKO — Passaggio di consegne per una nuova chat

**Aggiornato:** 20 ottobre 2026, Europe/Rome  
**Repository:** <https://github.com/PuritanoPuro/HAYKO>  
**Branch di lavoro:** `main`  
**Commit applicativo di riferimento prima di questo documento:** `64446d1` — `Use lighter HAYKO green for app icon`

## 1. Come usare questo documento

Questo file serve a dare a una nuova chat il contesto necessario per continuare lo sviluppo senza ripartire da vecchi pacchetti o perdere decisioni già approvate.

Prima di modificare il progetto:

1. leggere questo documento e i file in `docs/`;
2. controllare `git status`, il commit corrente e i file effettivamente presenti;
3. verificare il comportamento corrente sul simulatore;
4. confrontare la schermata interessata con Figma;
5. lavorare su una schermata o un flusso alla volta;
6. non ripristinare vecchi ZIP, updater o copie della precedente cartella `calcetto-mvp`.

Questo documento descrive lo stato noto, ma il codice e Supabase restano le fonti tecniche definitive. Se una descrizione non coincide con il comportamento reale, analizzare prima il codice e la configurazione distribuita.

## 2. Contesto dell’utente e metodo di lavoro

Il proprietario è Filippo Fuschini. Comunicare in italiano semplice e spiegare con chiarezza il risultato delle modifiche. Quando Filippo chiede di procedere, eseguire direttamente il lavoro disponibile, verificarlo e salvarlo nel repository.

Preferenze operative consolidate:

- seguire l’ordine numerico delle schermate Figma;
- perfezionare una schermata alla volta;
- chiedere chiarimenti prima di cambiare un comportamento non definito;
- mantenere tutta l’app coerente con Figma, compresi popup, dialoghi, menu e animazioni;
- non cambiare formule, dati, permessi o flussi durante un intervento puramente grafico;
- non cancellare cache, code offline o dati del simulatore per aggirare un errore;
- non reinstallare vecchi ZIP;
- avviare sempre l’app con la configurazione cloud locale;
- dopo ogni modifica rilevante aggiornare il simulatore e pubblicare il codice su GitHub.

## 3. Percorsi e ambiente

Repository locale:

```text
/Users/filippofuschini/APP CALCETTO/HAYKO
```

Applicazione Flutter:

```text
/Users/filippofuschini/APP CALCETTO/HAYKO/mobile
```

Ambiente verificato:

- Flutter 3.47.7 stable;
- Dart 3.13.5;
- macOS su Apple Silicon;
- Xcode 27;
- simulatore iPhone 18 Pro, iOS 27;
- ID simulatore noto: `673792EC-ABD0-4D81-B8F8-E03100C84FEF`.

Controllare comunque `flutter devices` prima di affidarsi all’ID.

## 4. Avvio corretto dell’app

La configurazione Supabase locale è in:

```text
mobile/cloud-config.local.json
```

Il file è escluso da Git e contiene soltanto URL e chiave pubblica del client. Non inserire mai chiavi `service_role`, segreti SMTP o credenziali amministrative nell’app o nella documentazione.

Comando corretto:

```sh
cd "/Users/filippofuschini/APP CALCETTO/HAYKO/mobile"
flutter run \
  -d 673792EC-ABD0-4D81-B8F8-E03100C84FEF \
  --target lib/main.dart \
  --dart-define-from-file=cloud-config.local.json
```

**Errore già diagnosticato:** una build avviata senza `--dart-define-from-file=cloud-config.local.json` mostra **“Impossibile avviare la connessione. Riprova”**. Non è necessariamente un guasto di Supabase. Il 20 ottobre 2026 l’app è stata ricompilata con la configurazione corretta; l’inizializzazione Supabase e il caricamento di “Le tue leghe” sono stati verificati.

Per una build Android configurata:

```sh
flutter build apk --debug --dart-define-from-file=cloud-config.local.json
```

## 5. Obiettivo del prodotto

HAYKO è un’app Flutter per iOS e Android dedicata al calcetto. Gestisce:

- account e profili privati;
- leghe amatoriali e competizioni;
- inviti e richieste di accesso;
- giocatori, squadre e rose;
- partite programmate, in corso e terminate;
- formazioni e portieri;
- gol, assist e autogol;
- statistiche individuali e di squadra;
- campionati e tornei;
- cache locale e sincronizzazione Supabase.

Lo smartwatch è un’evoluzione successiva e separata. I test mobile possono e devono iniziare prima dello sviluppo smartwatch. La specifica iniziale è in `watch/README.md`, ma non esistono ancora target watchOS, Wear OS o Zepp OS compilabili.

## 6. Struttura del repository

```text
mobile/      App Flutter iOS/Android, asset e test
supabase/    Migrazioni SQL correnti e template email
backend/     Motore Python di riferimento; non è il server dell’app
contracts/   Contratti storici dei comandi
docs/        Architettura, sviluppo, limiti e storico
watch/       Specifica preliminare smartwatch
```

File Flutter principali:

- `mobile/lib/main.dart`: bootstrap, splash minima, inizializzazione Supabase e link invito;
- `mobile/lib/app.dart`: tema, `MaterialApp` e gate dell’account;
- `mobile/lib/core/domain/`: modelli, regole delle partite, statistiche e competizioni;
- `mobile/lib/core/config/hayko_config.dart`: configurazione tramite `dart-define`;
- `mobile/lib/core/services/cloud.dart`: servizi cloud e parte dei flussi sociali;
- `mobile/lib/features/account/league_store.dart`: cache per account, coda offline e revisioni;
- `mobile/lib/features/home/`: schermata “Le tue leghe” e navigazione iniziale;
- `mobile/lib/features/leagues/`: creazione e gestione lega/giocatori;
- `mobile/lib/features/matches/`: formazioni, partita, gol e squadre;
- `mobile/lib/features/competitions/`: squadre, calendari, campionati e tornei;
- `mobile/lib/features/statistics/`: statistiche;
- `mobile/lib/design_system/`: colori, tema, home e splash;
- `mobile/lib/shared/`: componenti e presentazione condivisi.

Il nome interno del package è ancora `calcetto_mvp` per compatibilità. Il nome mostrato all’utente è HAYKO.

## 7. Identità grafica

Riferimento Figma principale:

<https://www.figma.com/design/CvfPybiKhi6bDSN1yl0aXC/HAYKO-%C2%B7-App-mobile>

Pagine/nodi usati:

- Leghe e identità: pagina `0:1`;
- Amatoriale: nodo `4:62`;
- Competizioni: nodo `4:63`;
- Home approvata: nodo `5:8`;
- Profilo: nodo `48:226`;
- Impostazioni: nodo `48:255`.

Regole di brand:

- nome definitivo: **HAYKO**;
- logo principale: falco originale, non monogramma H;
- non ridisegnare o approssimare il falco;
- font: **Bricolage Grotesque**, pesi 400, 600, 700 e 800 inclusi nel progetto;
- palette base dell’app:
  - sfondo `#0E2B22`;
  - superficie `#15392D`;
  - bordo `#2A5646`;
  - testo chiaro `#F2F5EE`;
  - testo secondario `#A9C2B6`;
  - lime `#E3F24A` quando previsto dal progetto;
- colori di lega, squadra e giocatore sono dati configurabili, distinti dal tema.

Asset master:

```text
mobile/assets/brand/hayko_falcon_no_black.svg
mobile/assets/brand/hayko_falcon_app_v2.svg
mobile/assets/brand/hayko_wordmark_clean.svg
mobile/assets/brand/hayko_app_icon.svg
```

### Icona app corrente

L’icona usa il falco V2 fornito nel pacchetto `HAYKO_APP_ICON_V2.zip`, su sfondo verde HAYKO `#0E2B22`. Lo stesso falco V2 trasparente è usato nell’header della home “Le tue leghe”; la splash conserva gli asset precedenti. Sono presenti tutte le dimensioni native iOS e Android. I PNG iOS non hanno trasparenza.

Ultimi commit relativi all’icona:

- `fb60333` — prima esportazione nativa;
- `18fffe1` — proporzioni del falco più vicine al riferimento;
- `64446d1` — precedente variante con sfondo verde più chiaro, poi sostituita dal falco V2 e dallo sfondo `#0E2B22`.

## 8. Navigazione e comportamento iniziale

Dopo splash e autenticazione, l’app deve aprire **“Le tue leghe”**. Non deve aprire automaticamente:

- “Nuova lega”;
- la creazione di una competizione;
- una lega specifica, salvo un flusso invito esplicito.

Questo errore si è già ripresentato durante lo sviluppo: verificare sempre l’avvio completo dopo modifiche a route, stato o navigazione.

## 9. Account, profilo, inviti e ruoli

- L’accesso è obbligatorio; non esiste modalità ospite.
- Autenticazione attuale: email/password, conferma email tramite codice e recupero password.
- Nome, cognome, nickname ed email sono obbligatori.
- Il profilo è privato; non implementare profili pubblici.
- Nome profilo e nome giocatore nella lega sono concetti distinti.
- Profilo e impostazioni sono schermate separate.
- Suoni, vibrazione e notifiche appartengono alle impostazioni.

Ruoli:

- chi crea la lega è presidente;
- solo il presidente nomina/rimuove admin ed elimina la lega;
- presidente e admin gestiscono giocatori, squadre, calendario, richieste ed eventi;
- il giocatore può consultare la lega approvata e modificare i propri dati consentiti;
- rimuovere l’accesso di un account non deve eliminare il giocatore sportivo, lo storico o le statistiche.

Flusso di ingresso:

1. link o codice invito;
2. richiesta di accesso;
3. approvazione/rifiuto da presidente o admin;
4. scelta del giocatore associato;
5. conferma;
6. possibilità di aggiungere il proprio nome se assente;
7. un giocatore associato non può essere rivendicato da un altro account.

La schermata intermedia 06 del vecchio flusso è stata eliminata. Per il codice si usa la schermata 07; per un link la stessa schermata mostra il nome della lega. “Membri e inviti” ha un notification dot in presenza di nuove richieste.

Terminologia UI approvata: preferire **giocatore** a **membro**, salvo i casi in cui si parla esplicitamente dell’accesso/account.

Nella gestione giocatori della lega:

- niente pulsante “Gestisci accesso alla lega” e relativo pannello;
- matita per promuovere/declassare admin;
- cestino rosso per rimuovere l’accesso.

## 10. Leghe amatoriali — decisioni implementate

- Footer: Partite, Giocatori, Statistiche.
- Pulsanti flottanti `+ Partita` e `+ Giocatore` in basso a destra, piccoli e coerenti con Figma.
- Il pulsante flottante non deve coprire la matita dell’ultimo giocatore.
- Aggiungi/modifica giocatore usa una schermata completa, non un popup; include nome e colore.
- Nomi nei campi di giocatori e squadre allineati secondo Figma, non centrati arbitrariamente.
- Le squadre salvate aprono direttamente la schermata di modifica.
- Nuova partita: nomi squadra con spaziatura verticale coerente con “Tipologia partita” e “Data e ora”.
- Selezione formazione: i giocatori scelti non cambiano posizione mentre si compone la stessa squadra.
- Passando alla seconda squadra, i giocatori già assegnati alla prima diventano disabilitati e vanno in fondo.
- Ricerca giocatore animata: lente a sinistra, `+ Giocatore` a destra; il campo si allarga al focus.
- Cliccando fuori, il campo ricerca si richiude senza cancellare il testo e il filtro resta attivo.
- Se il nome cercato non esiste, `+ Giocatore` compare in fondo alla lista filtrata.
- Conferma formazione e popup di riepilogo sono stati uniformati allo stile HAYKO.
- Portieri: “Fisso” e “A rotazione” hanno dimensioni Figma; drag-and-drop e menu non devono mostrare rettangoli/menu neri Material predefiniti.
- Nelle partite programmate è stata rimossa la sezione registro gol.
- Titolo del flusso gol: **“Assegna gol”**.
- I dialoghi “Termina partita” e “Rimuovi giocatore” sono compatti, senza spazio vuoto eccessivo.
- Il selettore orario usa due ruote Ore/Minuti in stile sveglia iPhone, senza orologio analogico.
- Tutti i dialoghi e popup devono usare pulsanti rettangolari stondati coerenti con l’app.

Statistiche amatoriali:

- tabella coerente con la classifica campionato;
- header a larghezza piena;
- linee orizzontali verde scuro tra i giocatori;
- nomi più distanti dal bordo sinistro;
- l’utente autenticato è indicato da una barretta laterale, non da una riga verde chiaro;
- non evidenziare automaticamente il primo classificato;
- l’indicatore segue il giocatore associato all’account che sta visualizzando le statistiche.

## 11. Competizioni — decisioni implementate

- Le competizioni sono un tipo di lega.
- Tipi: torneo a eliminazione e campionato.
- Footer: Partite, Squadre, Statistiche, Calendario.
- `+ Partita` usa lo stesso stile flottante delle leghe amatoriali.
- Nuova squadra: `+ Giocatore` e “Salva squadra” devono avere spazio sufficiente anche con rosa vuota.
- Aggiungi/modifica giocatore usa schermate complete in stile Figma, non popup.
- Le card squadra aprono direttamente “Modifica squadra”; eliminata la schermata intermedia inutile.
- Nomi squadra e giocatore seguono l’allineamento Figma.
- Configurazione calendario: niente trascinamento delle squadre.
- Gli slot di campionato/torneo usano menu a tendina per scegliere una squadra disponibile alla volta.
- Nei tornei il campo si chiama **“Fase del torneo”** e propone Finale, Semifinale, Quarti di finale ecc.
- Scelta assistman uniformata allo stile Figma anche dove manca un frame specifico.
- Classifica campionato: header verde chiaro fino al limite destro della tabella.
- Modifica giocatore nella squadra: schermata equivalente alla 21 Figma, non popup.
- Le schermate Marcatori e Assistmen non ripetono due volte lo stesso titolo.
- Tabellone torneo, vincitrice e statistiche competizione sono stati uniformati ai frame Figma.

## 12. Partite e controllo esclusivo

- La partita parte soltanto tramite pulsante, mai automaticamente all’orario previsto.
- Chi crea l’evento ne mantiene il controllo esclusivo per avvio, gol, annullamenti e conclusione.
- Essere presidente/admin non permette di prendere automaticamente il controllo di una partita creata da un altro account.
- Non consentire controllo simultaneo da più operatori.
- Viewer e operatore hanno capacità differenti.
- Le modifiche a partite concluse richiedono ancora una definizione completa di permessi e ricalcolo statistiche.

## 13. Dati, cache e sincronizzazione

Supabase corrente:

```text
https://xptztwrfjsznoumponxl.supabase.co
```

L’app usa Supabase Auth, RPC, RLS e documenti JSON revisionati. `LeagueStore` conserva snapshot e operazioni ordinate in `SharedPreferences`, separati per account. `Cloud.save` aggiorna lo stato locale e accoda/invia l’operazione. La sincronizzazione usa revisioni per evitare sovrascritture silenziose.

Migrazioni correnti:

```text
supabase/migrations/20261016_account_v1.sql
supabase/migrations/20261017_short_invites.sql
supabase/migrations/20261018_json_containment_precedence.sql
supabase/migrations/20261019_invite_preview.sql
supabase/migrations/20261020_allow_unused_player_removal.sql
```

La migrazione del 20 ottobre consente la rimozione di giocatori mai usati senza bloccare la sincronizzazione. È stata applicata al progetto Supabase corrente. Dopo la correzione, la coda locale è tornata a zero e la lega BFRC è stata verificata alla revisione 56.

Limiti ancora importanti:

- `LeagueStore.flush()` si interrompe sulla prima operazione rifiutata;
- un conflitto può bloccare anche operazioni successive;
- non esiste ancora un’interfaccia guidata di risoluzione conflitti;
- polling e refresh non equivalgono a realtime garantito;
- email, deep link, notifiche e concorrenza multi-device richiedono test reali.

Non modificare o rieseguire migrazioni alla cieca. Il repository non distribuisce automaticamente SQL su Supabase.

## 14. Inviti

- Codici brevi e link lunghi sono supportati.
- La pagina “Condividi invito” permette di copiare codice e link.
- Il popup “Copia codice invito” è stato uniformato allo stile HAYKO.
- I link correnti usano lo schema custom `hayko://join?invite=...`.
- Non è ancora presente un universal link HTTPS con fallback per chi non ha installato l’app.

## 15. Stato del restyling Figma

Le schermate principali di leghe, amatoriale e competizioni sono state percorse in ordine e uniformate. Profilo e impostazioni erano già stati considerati coerenti dall’utente. Gli ultimi interventi trasversali hanno riguardato:

- dialoghi di conferma e popup;
- altezza dei dialoghi termina partita/rimuovi giocatore;
- selettore orario a ruote;
- popup copia codice invito;
- dropdown e feedback drag-and-drop;
- tabelle statistiche/classifiche;
- eliminazione di titoli ridondanti;
- editor giocatori trasformati da popup a schermate;
- icona nativa dell’app.

Regola permanente: nessun nuovo dialogo, menu o overlay deve usare l’aspetto Material nero/predefinito se contrasta con il design HAYKO.

## 16. Verifiche e test

Comandi completi:

```sh
cd "/Users/filippofuschini/APP CALCETTO/HAYKO/mobile"
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

cd "/Users/filippofuschini/APP CALCETTO/HAYKO"
python3 -m unittest discover -s backend -p 'test_*.py'
```

La suite Flutter contiene attualmente **93 test**. Prima di dichiarare conclusa una modifica funzionale, eseguire almeno `flutter analyze` e `flutter test`. Per asset o configurazioni native verificare anche la build della piattaforma interessata.

Verifiche recenti:

- `flutter analyze`: nessun problema;
- 93 test Flutter passati prima degli ultimi soli aggiornamenti grafici dell’icona;
- build iOS Simulator riuscita;
- build Android debug riuscita;
- inizializzazione Supabase verificata;
- home “Le tue leghe” caricata con dati remoti;
- icona più chiara installata sul simulatore.

## 17. Funzioni ancora non completate

- login Apple e Google;
- universal link HTTPS e pagina fallback;
- Live Activities/Dynamic Island/widget partita;
- app smartwatch native e gateway autenticato dedicato;
- risoluzione guidata dei conflitti offline;
- editor completo dei risultati terminati con permessi e statistiche coerenti;
- validazione finale su più telefoni fisici e più account simultanei;
- test di distribuzione release e firma store.

## 18. Rischi e regressioni da controllare sempre

1. Avvio sulla pagina sbagliata invece di “Le tue leghe”.
2. Build senza configurazione cloud e falso errore di connessione.
3. Pulsanti flottanti che coprono l’ultima azione della lista.
4. Selezionati che cambiano posizione durante la stessa formazione.
5. Popup o dropdown neri non coerenti con HAYKO.
6. Titoli duplicati.
7. Evidenziazione del primo giocatore invece dell’utente autenticato.
8. Rimozione di un account che elimina per errore storico o statistiche.
9. Modifiche estetiche che cambiano formule o permessi.
10. Code offline bloccate da una singola operazione rifiutata.

## 19. Git e consegna

- Repository remoto: `PuritanoPuro/HAYKO`.
- Non includere `cloud-config.local.json`, build, cache o segreti.
- Conservare `pubspec.lock`.
- Scrivere commit focalizzati e descrittivi.
- Dopo la pubblicazione, riallineare la copia locale a `origin/main` e verificare `git status` pulito.

## 20. Primo messaggio consigliato per una nuova chat

È possibile allegare questo file e scrivere:

> Leggi `HAYKO_PASSAGGIO_CONSEGNE_CODEX.md`, poi analizza il repository e il comportamento attuale prima di modificare i file. Non ripristinare vecchi ZIP. Avvia sempre Flutter con `cloud-config.local.json`. Segui Figma una schermata alla volta, mantieni invariata la logica salvo mia richiesta esplicita e salva le modifiche su GitHub dopo le verifiche.

## 21. Documenti di supporto

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/DEVELOPMENT.md`
- `docs/KNOWN_ISSUES.md`
- `mobile/design/HAYKO_DESIGN_SYSTEM.md`
- `mobile/design/HAYKO_ACCOUNT_V1.md`
- `supabase/README.md`
- `watch/README.md`

La vecchia consegna `HAYKO_PASSAGGIO_CONSEGNE_CODEX.txt`, collocata fuori dal repository, descrive una fase precedente e contiene percorsi e stati ormai superati. Usare questo file `.md` come riferimento aggiornato.
