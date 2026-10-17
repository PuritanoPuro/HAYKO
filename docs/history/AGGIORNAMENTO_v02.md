# Aggiornamento v0.2 — 12 ottobre 2026

Lo stile resta quello della prima versione in attesa del prototipo Figma.

## Formazioni
Nome e formato → selezione squadra A → riepilogo conferma/modifica → selezione
squadra B → riepilogo → impostazione portieri. Nomi in ordine alfabetico,
selezione evidenziata, contatore N/formato e nessun giocatore in due squadre.
Si può tornare indietro. Selezionando un nuovo formato si azzerano i roster.
Non si supera il numero richiesto; conferma disponibile solo a squadra completa.

## Gol
Autogol: squadra beneficiaria → toggle + autore nella squadra avversaria →
portiere → riepilogo. Nessuna schermata assist. Portiere fisso nella squadra
che subisce: attribuzione automatica e nessuna schermata portiere, anche per
gli autogol. Indietro ripercorre soltanto i passaggi presenti; Annulla abbandona
la bozza. Restano gol senza assist e attribuzioni non indicate.

## Giocatori
Icona matita per modificare il nome; l'identificativo rimane uguale, così
presenze, gol e coppie non si perdono. Nelle leghe condivise editing riservato
al presidente e agli admin. Nella prova locale l'utilizzatore gestisce la lega.

## Portieri
Ogni nuova squadra può avere un portiere fisso oppure una rotazione.
Rotazione: ordine casuale iniziale, rimescolabile o modificabile con frecce,
intervallo 1–60 minuti (default 5), suono e vibrazione selezionabili.
Il primo giocatore del giro inizia in porta. Turno calcolato dal tempo trascorso
dall'avvio, non dal conteggio dei callback del timer: riaprire l'app non azzera
il giro. Schermata live con portiere previsto, conto alla rovescia e ordine.
Nella registrazione di un gol si sceglie chi era realmente in porta, con il
turno previsto indicato: la squadra potrebbe non aver rispettato il giro.

Notifiche telefono brevi, nessun pulsante per interrompere un allarme continuo.
L'avviso indica squadra e nome del nuovo portiere. Gli avvisi vengono cancellati
alla fine della partita. Coda globale delle prossime 60 scadenze, raggruppando
cambi simultanei: la copertura è mostrata nell'app e rinnovata al ritorno in
primo piano, al caricamento e alle modifiche. I turni sullo schermo continuano
anche oltre questa copertura. Non promettere avvisi infiniti senza riaprire l'app.
Su Android la schedulazione è inexactAllowWhileIdle, quindi il sistema può
ritardare un avviso: la puntualità a schermo spento va migliorata e provata
prima di usare il timer in partita. Su iOS sound/vibration dipendono dalle
impostazioni di notifiche, silenzioso, aptica e Focus: la vibrazione non è
controllabile separatamente come su Android. Il simulatore non prova l'aptica.
Le app watchOS/Wear OS/Zepp non sono ancora implementate; non c'è invio al polso.
Un Apple Watch potrebbe mostrare notifiche iPhone secondo il comportamento del
sistema, ma questo non equivale a un timer nativo o a supporto dichiarato.

## Statistiche
Tabella alfabetica: Giocatore, PG, V, S, GF, A, GS; scroll orizzontale.
Il filtro per formato agisce sulla tabella e su tutte le classifiche.
Solo partite terminate. I pareggi incrementano PG senza incrementare V o S.
Gli autogol contano nel punteggio e nei GS del portiere, non nei GF dell'autore.
Un annullamento rimuove l'evento da tutte le proiezioni.

Classifiche: gol/PG, assist/PG, (gol+assist)/PG. Ogni riga mostra totale, presenze
e media. Intesa: gol assist-marcatore A→B e B→A sommati una sola volta per evento,
divisi per il numero di partite in cui i due erano nella stessa squadra, anche
quando non hanno prodotto gol. Una coppia avversaria non accumula presenze
insieme. Sono incluse coppie a zero con presenze; non ci sono righe senza
denominatore. Parità risolta con totale e nome. Non viene inventata una media
GS/minuto, perché non registriamo tiri e tempo effettivo in porta.

## Condivisione
Client Flutter + RPC Supabase in backend/social_v02.sql, da attivare in un
progetto Supabase. Senza configurazione, la sezione indica che non è attiva,
senza generare inviti locali che fingono di funzionare.
Le leghe condivise vengono create nella nuova sezione; quelle locali restano
separate e conservano i dati. Non c'è ancora importazione delle leghe locali.

Accesso via codice email; invito copiabile con codice casuale, durata 7 giorni,
massimo 100 nuovi iscritti e revoca. Il destinatario incolla il link o il codice
in “Entra con un invito”; apertura automatica tramite link NON configurata.
Primo ingresso: scelta di un giocatore libero o inserimento di un nome nuovo.
Un giocatore associato non si riassegna ad altri account. La scelta si basa
sull'onestà dei partecipanti: l'account email è verificato, l'identità sportiva
non è verificata da un documento o dal presidente. Una futura rettifica
amministrativa deve avere audit; non fare merge automatico dei nomi uguali.

Creatore lega = presidente. Presidente promuove/rimuove admin tra membri
associati. Admin e presidente creano eventi, ma SOLO il creatore dell'evento
ne avvia/termina la partita, registra e annulla gol. Un admin non può alterare
gli eventi degli altri, nemmeno se presidente. Se si revoca il ruolo admin,
il creatore mantiene la registrazione dei propri eventi esistenti.

Il server controlla permessi e transizioni; tabelle senza accesso diretto
per client, RPC con auth.uid(), search_path fisso, lock di lega e revisione.
Un conflitto richiede aggiornamento e ripetizione esplicita; niente merge cieco.
Questo MVP usa snapshot JSON di lega, limitati a 5 MiB, 200 giocatori e 1000
partite: è un percorso iniziale, diverso dal modello analitico normalizzato
progettato in v0.1. Anche eventi diversi della stessa lega possono confliggere.
Non c'è outbox cloud: scritture richiedono rete. Il match condiviso aggiorna
ogni 5 secondi mentre la pagina è aperta; altre sezioni usano Aggiorna.
Nessun Realtime né feed amici in questa release.

## Compatibilità e verifica
Stessa chiave locale calcetto.v1. I dati precedenti vengono caricati come
portiere manuale: non si cambia retroattivamente chi ha subito i gol.
Copia iniziale delle preferenze in calcetto.backup_before_v02.
Lo script di aggiornamento conserva host iOS/Android e identificativo app,
salva backup dei file modificati e configura notifiche native.

Verifiche eseguibili qui: 12 test Python del motore v0.1 e 3 test dell'updater.
Test Flutter forniti: 5 originali + 9 nuovi, da eseguire sul Mac.
Test SQL sociale fornito in una transazione con rollback, SOLO su database
di test. Non eseguito qui: mancano PostgreSQL, Flutter, Xcode e dispositivi.
App social e notifiche native restano da compilare e provare prima della beta.

## Fonti tecniche
- Notifiche e setup nativo (versione bloccata): https://pub.dev/packages/flutter_local_notifications/versions/19.5.0
- Auth OTP Flutter: https://supabase.com/docs/reference/dart/auth-signinwithotp
- Verifica OTP: https://supabase.com/docs/reference/dart/auth-verifyotp
- RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
