# v0.3 — lega, colori, eventi e competizioni (13 ottobre 2026)

## Leghe e colori
Impostazioni della lega: nome, colore primario, colore secondario e cancellazione
con conferma. Nelle leghe condivise queste operazioni spettano al presidente;
presidente e admin possono personalizzare i giocatori e i preset delle squadre.
La cancellazione rimuove tutti i contenuti di quella lega, non le altre leghe.
Sono cancellati anche gli avvisi del giro portiere legati alla lega eliminata.
Palette e codice #RRGGBB consentono la scelta dei colori; in app sono salvati
interi ARGB opachi. Il colore del giocatore si vede negli elenchi, nella tabella
e nelle scelte del gol. Quello delle squadre si sceglie creando l'evento, oppure
modificando un preset nelle impostazioni. Nome e colore di un preset mantengono
lo stesso ID per conservare la sua classifica. Le vecchie partite mantengono
i nomi e colori registrati nell'evento, come fotografia della partita.

## Eventi
Data e ora sono impostate in creazione, il luogo è testo obbligatorio.
Date salvate in UTC, visualizzate nell'ora locale del telefono. Il pulsante
Modifica data, ora e luogo è disponibile al creatore solo quando l'evento è
programmato. Dopo l'avvio il modello e il server impediscono la modifica.
Non è stato aggiunto un avvio automatico, neppure se l'orario è già passato.
Le vecchie partite senza dettagli mostrano “Data e ora non indicate”, senza
inventare valori. Il tempo trascorso compare anche nella lista In corso e si
aggiorna ogni secondo; usa startedAt e continua se si riapre la schermata.

## Preset
Nel riepilogo della formazione si può scegliere Salva squadra come preset e
assegnare un nome. Salvataggio indipendente dall'evento: il preset resta anche
se poi si abbandona la creazione della partita. I nomi dei preset sono distinti.
Nelle selezioni successive, Carica una squadra salvata mostra i preset del
formato adatto e riempie nome, giocatori e colore. La formazione della nuova
partita si può modificare senza cambiare il roster originale del preset.
La squadra mantiene il proprio ID anche con una formazione diversa: è l'identità
del club, non una coppia anonima di liste di giocatori. Se due preset hanno
giocatori in comune, occorre correggere la formazione: nessuno può stare in
entrambe le squadre di una stessa partita.

## Competizioni
Nuova sezione Competizioni. Per crearne una servono almeno due preset salvati
con lo stesso formato. Partecipanti selezionati alla creazione, nessuna
iscrizione aggiuntiva durante il torneo in questa release.
Il campionato permette di associare gli eventi a due squadre iscritte e calcola
PG, V, P, S, GF, GS, differenza reti e punti (3 vittoria, 1 pareggio, 0 sconfitta).
Ordine: punti, differenza reti, GF, nome. Non viene generato automaticamente
un calendario di andata/ritorno: si creano e programmano le partite desiderate.

Torneo a eliminazione: 2, 4, 8 o 16 squadre, senza bye in questa versione.
L'ordine di selezione determina gli accoppiamenti del primo turno. In creazione
partita si sceglie un incontro disponibile del tabellone; nome, ID e giocatori
dei preset sono proposti automaticamente, con la consueta conferma formazione.
Il successivo turno diventa disponibile quando TUTTI gli incontri del turno
precedente sono conclusi. Ogni coppia ha un solo evento. In caso di pareggio
il creatore deve scegliere la squadra qualificata (per esempio dopo rigori
giocati sul campo). Questa scelta non aggiunge gol al punteggio né ai giocatori.
Si mostrano incontri, stato Eliminata/In gara/Vincitrice e statistiche squadra;
non si assegnano punti di classifica per determinare chi avanza nel knockout.
Le squadre avanzano per risultato/qualificazione, non per l'ordine della tabella.

Le classifiche delle squadre considerano solo le partite terminate della
competizione selezionata. Le amichevoli continuano a contribuire alle statistiche
dei giocatori, ma non a una classifica di campionato o torneo.

## Server condiviso
Il client aggiunge questi campi allo snapshot. Per le leghe condivise serve
backend/social_v03.sql DOPO social_v02.sql. È una migrazione transazionale da
applicare una sola volta prima di usare il client v0.3 online. Non è stata
eseguita qui, e non esiste ancora un progetto Supabase attivato per Filippo.
La migrazione preserva gli eventi storici, aggiunge default ai colori e aggiorna
la validazione server di preset, competizioni, qualificazioni e tabellone.
Date/luogo bloccati dopo l'avvio; associazione evento/preset/competizione stabile;
le regole di creazione e registrazione dell'evento restano quelle precedenti.
bc_delete controlla il presidente e rimuove lega, membership, inviti e audit
nella stessa transazione. Gli account Supabase non vengono cancellati.

## Aggiornamento e verifiche
La patch aggiorna sorgenti, test e SQL, non i progetti nativi o le dipendenze.
Il percorso predefinito è ~/APP CALCETTO/calcetto-mvp. Prima di scrivere verifica
la versione dei file e salva backup; non modifica i dati del simulatore.
I campi nuovi hanno default compatibili con v0.2.1. La copia delle preferenze
precedenti viene mantenuta prima di salvare il nuovo formato.

9 test Flutter nuovi: migrazione, dettagli bloccati, colori/preset, punti,
turni knockout, pareggio, UI dettagli, conferma cancellazione e salvataggio
preset. Aggiornate le prove precedenti perché ora richiedono il luogo.
Totale previsto: 28 test. Questa v0.3 non è stata compilata/testata con Flutter
qui: manca l'SDK. La v0.2.1 precedente aveva passato analyze e 19 test sul Mac.
Test SQL fornito da eseguire soltanto su Supabase di test; non eseguito qui.
