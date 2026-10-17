# Bordo Campo — specifica tecnica MVP v0.1

Nome di lavoro modificabile. Data: 10 ottobre 2026.

## 1. Obiettivo e stato della consegna

Un giocatore organizza una partita nella lega; un registratore scelto aggiunge
gol, assist e il giocatore che era in porta in quel preciso momento. Il mobile
deve poter svolgere tutto senza smartwatch. I membri consultano punteggio,
statistiche individuali e intesa tra coppie, con filtro per formato.

Il pacchetto include un MVP Flutter locale, un motore transazionale Python
eseguibile e verificato, test Dart, schema PostgreSQL con isolamento di lettura,
contratto JSON e progetto delle tre integrazioni smartwatch. Il motore Python
è un laboratorio di concorrenza separato: il Flutter non lo chiama. Non sono
ancora implementati gateway HTTP, account, sincronizzazione, amici o app native
watch. Il risultato è una base di sviluppo, non un servizio multiutente pronto
né una build installabile. Nessun account esterno è stato creato.

## 2. Decisioni iniziali

| Tema | Scelta MVP condiviso |
|---|---|
| Mobile | Flutter iOS + Android; nucleo di dominio separato dalla UI |
| Server | Supabase Auth, PostgreSQL, RPC transazionali, Realtime |
| Watch | SwiftUI/watchOS, Kotlin/Wear OS, JavaScript/Zepp OS |
| Registrazione | Un account registratore designato, più dispositivi di quell'account ammessi |
| Trasferimento | Organizzatore trasferisce il ruolo con comando online |
| Squadre | Numero 2–11 per squadra, roster congelato dopo avvio |
| Assenze | Assente escluso dal roster; nessuna presenza attribuita |
| Dati mancanti | Marcatore, assist e portiere nullable, senza inventare valori |
| Autogol | Squadra beneficiaria + autore nella squadra che subisce; nessun assist |
| Fine partita | Conferma esplicita; blocca nuovi gol e annullamenti standard |
| Risultati | Calcolati dai gol non annullati, non contatori modificabili |
| Statistiche | Solo partite terminate; archiviate incluse quando introdotte |
| Privacy iniziale | Leghe private, letture consentite ai soli membri |

Queste scelte sono default progettuali modificabili. Il registratore è un
account, non un portiere fisso: chi subisce viene selezionato per ciascun gol.
Più watch possono consultare insieme; cambiare chi registra richiede un
trasferimento esplicito del ruolo. Il consenso verbale dei giocatori resta
necessario per scegliere chi registra il singolo episodio.

## 3. Architettura e confini

| Modulo | Responsabilità |
|---|---|
| Mobile presentation | Leghe, roster, schede partite, wizard gol, statistiche |
| Mobile domain | Invarianti di squadre/gol, stato partita, proiezioni statistiche |
| Mobile data | Repository, database locale, outbox, cache snapshot, gateway |
| Gateway | Autenticare sessione, validare schema, rate limit, autorizzare pairing |
| RPC database | Lock partita, autorizzazione, revisioni, deduplicazione, commit |
| Watch clients | Bozza gol, outbox, relay, punteggio ufficiale e stato connessione |
| Realtime | Notificare nuova revisione dopo commit; trigger per refetch |

Il server determina identità e permessi; `actor_id` dal payload non è accettato.
Gli orologi condividono il contratto, non lo stesso codice UI. Il servizio Zepp
è un client indipendente del gateway, non un plugin Flutter implicito.

Flutter supporta entrambi i sistemi mobile. Verificare le versioni minime con
la release Flutter e i plugin effettivamente bloccati nel lockfile. In questa
prima base le piattaforme host vengono generate con `flutter create` e il
lockfile verrà prodotto da `flutter pub get`, poi va versionato.

## 4. Flussi e schermate

Navigazione condivisa prevista: Leghe, Amici, Profilo. In una lega: Partite,
Giocatori, Statistiche. Nella base locale consegnata esistono Leghe e le tre
sezioni interne; Amici e Profilo richiedono identità e non sono simulati.

1. Creazione lega: nome, organizzatore, invito privato nella versione online.
2. Giocatori: account oppure ospite con identità distinta dal nome visibile.
3. Partita: formato, data prevista nella versione online, nomi delle squadre,
   selezione di esattamente N giocatori per squadra, nessun duplicato.
4. Avvio: organizza roster e assegna registratore; start incrementa revisione.
5. Live: punteggio grande, GOL, cronologia e annullamento del singolo gol.
6. Gol: squadra → marcatore → assist/nessuno → portiere/non indicato → conferma.
7. Prima della conferma, Annulla abbandona la bozza senza cambiare punteggio.
8. Dopo conferma, Annulla gol invia una mutazione con audit, senza cancellare
   il record originale. Il MVP consente di annullare anche gol precedenti.
9. Fine: conferma, risultato definitivo, aggiornamento statistiche.

Gli eventi senza marcatore sono validi per il risultato e indicati come
incompleti. Nel locale non c'è ancora modifica dei metadati: durante la partita
si può annullare e registrare nuovamente. Le correzioni a partita conclusa
richiederanno un comando amministrativo auditato nella fase successiva.
Non riaprire automaticamente una partita per consegnare una coda offline.

## 5. Modello dati

| Entità | Campi e vincoli significativi |
|---|---|
| profiles | user_id Auth, nome, foto futura |
| leagues | id, nome, created_by, created_at |
| league_members | league_id + user_id univoci, owner/admin/member |
| players | id stabile per lega, user_id nullable, display_name |
| matches | league, organizer, recorder, formato, nomi A/B, stato, revisione, date |
| match_players | match + player univoci, squadra 0/1, stesso league_id |
| goals | squadra beneficiaria, own_goal, scorer/assist/keeper nullable, voided_at |
| command_receipts | match + command_id univoci, actor, richiesta canonica, risposta |
| match_audit | revisione univoca per partita, attore, comando, dettagli, data server |
| friendships (fase online) | coppia utenti ordinata, requested_by, pending/accepted/blocked |
| league_invites (fase online) | hash token, expiry, max_uses, used_count, lega |
| device_links (fase watch) | utente, device id, credenziale limitata, scadenza, revoca |

Il player di lega non coincide con auth user. Un ospite può essere associato
a un account con verifica dell'organizzatore, senza cambiare gli ID storici.
Il confronto tra leghe usa user_id; ospiti senza associazione non si fondono
automaticamente in base al nome. I nomi duplicati sono ammessi ma la UI online
deve distinguerli con alias/avatar, senza usarli come identificativi.

Il file schema.sql contiene le prime nove entità, vincoli di appartenenza al
roster e RLS di lettura. Non verifica da solo la dimensione dei roster o le
transizioni di stato: devono farlo le RPC. La creazione lega + membership
owner e il provisioning profilo devono avvenire con operazioni server atomiche.
Lo schema non autorizza le scritture dirette dei client, e non è una migrazione
completa da applicare a un'app di produzione.

## 6. API progettata

Tutte le route sono proposte: non sono già esposte dal codice consegnato.
Bearer Auth verificata dal gateway; nessuna service_role nei dispositivi.

| Metodo/route | Uso | Permesso |
|---|---|---|
| POST /v1/leagues | Creare lega e owner atomici | Utente autenticato |
| GET /v1/leagues | Leghe dell'utente | Utente autenticato |
| POST /v1/leagues/{id}/players | Inserire ospite/account | Admin/owner |
| POST /v1/leagues/{id}/matches | Creare evento e roster | Admin/owner |
| GET /v1/matches/{id} | Snapshot roster, stato, punteggio, revisione | Membro lega |
| POST /v1/matches/{id}/commands | Start, finish, goal, void, transfer | Secondo comando |
| GET /v1/leagues/{id}/stats?format=5 | Aggregate individuali e coppie | Membro lega |
| POST /v1/watch/pairings | Codice monouso con TTL breve | Utente mobile |
| POST /v1/watch/pairings/redeem | Credenziale device limitata | Codice valido |
| DELETE /v1/watch/devices/{id} | Revocare device | Proprietario |

`command.schema.json` descrive l'envelope v1. Validazione JSON Schema con
format-checking UUID/date attivo, poi controllo del dominio. Revisioni server
bigint, snapshot serializzato in modo coerente nei client; se si superasse
il range numerico sicuro JavaScript introdurre versione protocollo a stringa.
Nella base Flutter gli ID sono token casuali hex di 128 bit; nella versione
online occorre migrarli esplicitamente a UUID, prima di collegare l'API.

ACK: command_id, revision, score [A,B], status. Il gateway aggiunge
protocol_version e match_id. Snapshot: roster, nomi, stato, recorder_id,
revision, score, elenco gol e server_time. Nessun token nelle risposte di match.
Un ACK da solo non contiene tutti i dati: il client fa refetch se necessario.
Il punteggio durante il wizard resta quello confermato.

| Errore | HTTP previsto | Azione UI |
|---|---|---|
| INVALID_COMMAND / INVALID_* | 422 | Correggere bozza, nessuna mutazione |
| Sessione non valida/scaduta | 401 | Riautenticare o ripetere pairing |
| FORBIDDEN / NOT_RECORDER | 403 | Sospendere coda, mostrare perdita ruolo |
| NOT_FOUND | 404 | Rimuovere cache solo con decisione utente |
| REVISION_CONFLICT | 409 | Snapshot nuovo, riconciliazione esplicita |
| ID_REUSED | 409 | Bloccare comando: bug o payload modificato |
| INVALID_STATE | 409 | Partita non adatta; conserva bozza da risolvere |
| Timeout / 5xx | — | Retry stesso ID e stesso envelope con backoff |

Nel motore Python il gateway è simulato: match_id e actor sono argomenti,
e la funzione riceve solo command_id/type/expected_revision/payload. Gli ID
dei test sono brevi per leggibilità; non validano l'envelope UUID completo.
SQLite salva lo snapshot come JSON per rendere il laboratorio piccolo;
la produzione userà tabelle normalizzate e transazioni PostgreSQL.

## 7. Concorrenza, doppio gol e transazioni

Algoritmo RPC: iniziare transazione → lock riga match → verificare membership
e device → cercare receipt → autorizzare comando → confrontare revisione →
validare stato/roster → mutare gol/stato → incrementare revisione → audit +
receipt nella stessa transazione → commit → pubblicare nuova revisione.

Receipt esistente con stessa identità e richiesta restituisce la risposta
originale, anche se la partita è stata poi chiusa o il ruolo trasferito.
Receipt stesso ID ma attore/payload diverso viene rifiutata. App e relay devono
preservare lo stesso envelope: non rigenerare ID o revisione nei retry.

Idempotenza risolve le ritrasmissioni dello stesso comando, non riconosce un
medesimo episodio reale registrato con due ID differenti. Due dispositivi del
registratore che inviano dalla stessa revisione: uno vince, il secondo riceve
conflitto. Nessun retry automatico del secondo con revisione aggiornata: chiedere
se era lo stesso gol oppure un gol diverso. Se davvero diverso, il nuovo
tentativo ha un nuovo ID, la revisione aggiornata e conferma esplicita.
Se il secondo dispositivo ha già ricevuto il primo aggiornamento, due episodi
identici potrebbero ancora essere registrati due volte: mostrare eventuale
somiglianza come avviso, mai eliminare automaticamente gol per vicinanza temporale.

Un ruolo registratore singolo riduce il problema ma non prova l'unicità fisica
dell'episodio. Il registro con annullamento resta essenziale. L'orario watch
è indicativo, l'ordine ufficiale è la revisione server.

## 8. Offline e realtime

Nel locale consegnato non c'è outbox: il telefono è l'unico archivio.
SharedPreferences salva snapshot semplici per una prova individuale; non è il
database finale per registrazione affidabile durante uso prolungato.
Per MVP condiviso usare SQLite sul mobile, storage locale appropriato sui
watch, e outbox persistente con stati queued/sending/acknowledged/conflict/rejected.

Prima dell'invio persistere ID e payload. Inviare un comando per volta per
partita; un comando in attesa blocca finish/transfer dalla stessa outbox.
Durante rete assente mostrare punteggio ufficiale ultimo noto e numero eventi
in attesa. Punteggio provvisorio eventuale separato e chiaramente etichettato.
Non generare un contatore locale che diventi ufficiale al ritorno della rete.

Per più bozze offline: la coda assegna expected_revision quando la bozza arriva
in testa e viene trasformata per la prima volta in comando persistito. Dopo
questa assegnazione, il comando è immutabile fino all'ACK. Una nuova revisione
inaspettata blocca e richiede riconciliazione. Le bozze successive restano bozze.

Cambio ruolo o chiusura da un altro device prevalgono sui comandi tardivi.
Perdite realtime sono normali: refetch al foreground, alla riconnessione e
dopo ACK. Applicare snapshot solo se revision >= cache.revision. Realtime è un
segnale per aggiornare cache, non un'unica garanzia di consegna.
Configurare replica e canali privati con controlli membership: RLS delle
tabelle non equivale automaticamente ad autorizzazione di qualsiasi broadcast.

## 9. Statistiche e significato

Base del calcolo: partite della lega concluse, filtro format applicato PRIMA
di aggregare, gol con voided_at null. Non aggregare i contatori visualizzati
dal dispositivo. Nessun autogol attribuito al totale gol dell'attaccante.

| Metrica | Definizione |
|---|---|
| Gol | Gol normali attribuiti al player |
| Assist | Assist validi attribuiti al player; esclusi autogol |
| Contributi | Gol + assist individuali |
| GS | Gol con keeper_id uguale al player |
| Autogol | Episodi own_goal attribuiti al player |
| Presenze | Numero match conclusi con player nel roster |
| Vittorie/pareggi/sconfitte | Confronto risultato della squadra del player |
| Gol/partita | Gol / presenze, null se presenze=0 |
| Assist/partita | Assist / presenze, null se presenze=0 |
| Coppia A+B | Un evento normale con assist A→gol B o B→A, conteggiato una volta |
| Coppia direzionale (successiva) | A→B e B→A distinti per dettaglio |

La coppia non conta tutti i gol di due compagni: richiede legame diretto
assist-marcatore nell'episodio. Un gol senza assist o marcatore non entra nella
classifica coppie. Gol con portiere sconosciuto restano nel risultato ma non
nei GS di un giocatore. Mostrare copertura di attribuzione nella versione
online per evitare una classifica apparentemente completa quando mancano dati.

Non calcolare GS/minuto, percentuale parate o media per presenza in porta:
non registriamo minuti in porta né tiri. La presenza nella partita non equivale
a minuti da portiere. Coppie vincenti: fase successiva, denominatore partite
giocate insieme nella stessa squadra; evitare classifiche senza minimo presenze.

## 10. Sicurezza, amici e dati personali

RLS sempre attiva, nessuna scrittura diretta dei client sulle tabelle partita.
Una RPC SECURITY DEFINER richiede search_path fisso, privilegi minimi, controllo
esplicito auth.uid(), membership, ruolo e locking. Il backend con credenziale
privilegiata deve ricontrollare l'identità verificata; non fidarsi del JSON.
Schema incluso: lettura del proprio profilo e roster coi nomi dei membri,
nessuna esposizione indiscriminata dei profili globali.

Pairing watch: codice casuale monouso a breve scadenza, hash salvato server,
limite tentativi, credenziale revocabile legata a utente/device e solo route
necessarie. Il codice non è il token permanente. Su Zepp verificare storage
disponibile: non presumere il Keychain di iOS dentro il Mini Program.

Amici: richiesta da accettare, blocco e revoca, leghe in comune ottenute
intersecando membership. Essere amico non concede lettura di una lega privata.
Inviti con token scadente, consumo atomico e permessi controllati. Profili
complessivi includono soltanto statistiche a cui il lettore può accedere.

Prima della beta esterna definire esportazione dati, cancellazione account,
gestione storico e pseudonimizzazione, informativa e moderazione. Questo
documento progetta i controlli tecnici, non costituisce una verifica legale.

## 11. Compatibilità watch verificata

| Piattaforma | Percorso iniziale | Limite da validare |
|---|---|---|
| Apple Watch | WCSession con iPhone, UI SwiftUI | Reachability e background, ACK server distinto |
| Wear OS | Data Layer con Android; HTTP indipendente opzionale | Data Layer non disponibile con iOS |
| Bip 5 / Zepp | Device App + Side Service Zepp via HTTPS | API 2.1, background Zepp e persistenza su device reale |

La tabella ufficiale Zepp elenca Bip 5 con API_LEVEL e OS 2.1 e display
320×380, distinto da Bip 5 Unity (3.0). Quindi è un target concreto per un PoC,
non una garanzia che ogni API moderna o connessione continua sia disponibile.
La matrice di abbinamento va per modello; supportare più sistemi non significa
che tutti gli orologi si abbinino con entrambi i sistemi telefonici.

## 12. Lavoro successivo e criteri di uscita

| Incremento | Risultato verificabile |
|---|---|
| A — locale (questo pacchetto) | Creare roster, avviare, segnare, annullare, terminare, statistiche persistite |
| B — base condivisa | Auth, repository remoto, RPC, RLS testata, due telefoni stesso punteggio |
| C — tre PoC watch | Stesso comando v1 invia un gol da watchOS, Wear OS e Bip 5 reali |
| D — beta durante partita | Outbox persistente, riavvio senza perdita, ruolo trasferibile, riconciliazione |
| E — social e correzioni | Amici, inviti, profili, metadati gol modificabili e audit postpartita |

Per B: test accesso incrociato tra leghe, RPC simultanee, perdita connessione
dopo commit prima di ACK, annullamento che corregge ogni proiezione, invalid
roster e membership. La transazione deve includere receipt + audit + mutazione.
Per C/D: eseguire test su iPhone + Apple Watch, Android + Wear OS, telefono +
Bip 5; includere Zepp in background e switch Bluetooth. Misurare numero tocchi,
tempo di registrazione e leggibilità mentre si gioca prima di ottimizzare.
Per la beta: build mobile compilate e testate, nessuna perdita dati in crash,
nessun dato leggibile da non membri, stato pending visibile su ogni device.

## 13. Verifiche di questa consegna

12 test Python passati: retry, doppio invio simultaneo, conflitto tra due ID,
autorizzazione, cambio registratore, autogol, roster, assist a se stesso,
annullamento e stato partita. Non provano il server PostgreSQL né il trasporto.
5 test Dart forniti, NON eseguiti: Flutter/Dart non sono installati qui.
Schema PostgreSQL NON eseguito: nessun database PostgreSQL disponibile.
Nessuna build Android/iOS/watch, nessuna prova sui dispositivi reali.

## 14. Fonti ufficiali consultate

- Flutter piattaforme: https://docs.flutter.dev/reference/supported-platforms
- Apple WatchConnectivity: https://developer.apple.com/documentation/WatchConnectivity/transferring-data-with-watch-connectivity
- Wear OS Data Layer: https://developer.android.com/training/wearables/data/overview
- Zepp architettura: https://docs.zepp.com/docs/guides/architecture/arc/
- Zepp dispositivi: https://docs.zepp.com/docs/reference/related-resources/device-list/
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
