# Aggiornamento v0.4

La creazione della lega distingue Amatoriale e Competizione.

- Amatoriale: Partite, Giocatori, Statistiche. Nessuna voce Competizioni nel footer.
- Competizione: Partite, Squadre, Statistiche, Calendario.
- Le leghe senza competizioni precedenti restano amatoriali. Quelle che contenevano competizioni assumono il tipo Competizione; tutti i dati restano presenti. Se esistono più competizioni precedenti, il Calendario offre accesso all'archivio delle altre.
- La configurazione iniziale comprende eliminazione o campionato, formato da 2v2 a 11v11, sola andata oppure andata e ritorno.
- Una competizione può essere salvata prima di creare le squadre. Un campionato richiede almeno due squadre; l'eliminazione richiede 2, 4, 8 o 16 squadre.
- Le squadre possono avere riserve, fino a 60 giocatori. I numeri di maglia sono per squadra, da 0 a 99, senza duplicati. In fase di inserimento sono proposti numeri liberi modificabili. La partita carica inizialmente i primi N giocatori della rosa; la formazione resta modificabile.
- Squadre e rose si modificano prima di programmare la prima partita. I giocatori si possono aggiungere durante la creazione della squadra o della partita.
- Il Calendario consente sorteggio oppure configurazione dell'ordine delle squadre tramite trascinamento. Questo ordine determina gli accoppiamenti: nel campionato le giornate sono calcolate con il metodo circolare; nel torneo il primo incontra il secondo, il terzo il quarto, ecc. Non è un editor di ogni singola giornata indipendente.
- Date, orari e luoghi si impostano premendo gli incontri del calendario e restano modificabili nelle partite programmate. Nessun avvio automatico.
- L'andata/ritorno inverte la coppia delle squadre, distingue le giornate e non conta la stessa partita per entrambi gli incontri. I calendari dispari mostrano i riposi.
- Le Statistiche comprendono classifica squadre o tabellone e la tabella giocatori con classifiche marcatori/assistmen; contano solo le partite della competizione selezionata.
- Il tabellone mostra gli incontri determinati e aggiunge i turni successivi quando tutte le qualificate del turno precedente sono note.

## Verifiche

Il workspace non ha Flutter installato. Sono stati aggiunti nove test Flutter significativi, da eseguire sul Mac insieme ai 35 precedenti. Lo script Python è distribuito in ASCII e verifica gli hash prima di modificare file; crea un backup e non modifica i dati del simulatore. Il caricamento dell'app salva anche una copia dei dati locali prima della migrazione.

## Cloud

Il nuovo formato JSON richiede `backend/social_v04.sql`, dopo le migrazioni v02 e v03. La migrazione è inclusa ma non è stata eseguita o verificata su Supabase. Aggiorna la validazione, distingue il tipo di lega, supporta rose con riserve, numeri di maglia, competizioni in preparazione e andata/ritorno. La configurazione online resta un'attività separata; l'app locale non richiede server.
