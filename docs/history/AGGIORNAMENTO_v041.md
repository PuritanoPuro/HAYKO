# Aggiornamento v0.4.1

## Competizioni

- Il pulsante di creazione squadra mostra un'unica icona + seguita da Squadra.
- L'editor della squadra contiene solo la sua rosa. Aggiungere un giocatore significa inserire nome e numero: entra direttamente nella rosa senza successiva selezione. Il colore deriva dalla squadra.
- Giocatori e numeri sono modificabili; la rimozione riguarda la rosa, senza eliminare le identità che servono a conservare i risultati precedenti. Una squadra può essere salvata con rosa incompleta e completata successivamente. Prima di creare o avviare un incontro ciascuna squadra deve avere almeno N giocatori per il formato NvN.
- Le rose possono essere modificate anche dopo la programmazione delle partite. Quelle programmate registrate dallo stesso utente vengono aggiornate quando la squadra viene salvata; all'avvio viene comunque acquisita l'intera rosa attuale. Le partite iniziate e terminate conservano la rosa acquisita e i loro eventi.
- La creazione partita richiede solo squadre, data e ora; nessuna selezione dei giocatori, dei portieri o della rotazione. Tutti i giocatori della rosa (fino a 60), incluse le riserve, compaiono nella registrazione gol/assist.
- Gol normali: squadra, marcatore, eventuale assist, riepilogo. Autogol: squadra beneficiaria, autore nella squadra avversaria, riepilogo. Nessun portiere e nessun avviso di rotazione nelle competizioni. I dati storici dei portieri non vengono cancellati dal registro dati, ma non sono mostrati nella nuova interfaccia.
- Nella lista partite si mostra soltanto la giornata o il nome del turno, senza ripetere il nome della competizione.
- Statistiche: classifica squadre oppure tabellone, poi Marcatori e Assistmen, ordinati per totale. Nessun filtro formato e nessuna tabella generale dei giocatori.
- Classifica squadre con colori, punti e DR (differenza reti).
- Turni del torneo: Ottavi di finale, Quarti di finale, Semifinali, Finale.
- Trofeo sulla squadra vincitrice dopo la finale, oppure dopo la conclusione di tutti gli incontri del campionato. Punti, DR e GF determinano il primo posto; una parità completa produce un primo posto condiviso.

## Tutte le leghe

Il luogo è facoltativo sia nella creazione sia nella modifica di un evento programmato. Il cronometro totale e l'avvio manuale restano disponibili.

## Verifiche e installazione

Lo script ASCII verifica gli hash, crea un backup ed è riapplicabile. Non cancella i dati del simulatore. Sono stati aggiornati i test v04 per il nuovo inserimento diretto e aggiunti 10 test v041. Totale previsto: 54. Flutter non è presente nel workspace: analisi e test devono essere eseguiti sul Mac.

Per il cloud è inclusa `backend/social_v041.sql`, da applicare dopo v02, v03 e v04 su un ambiente di test. Aggiorna la validazione delle rose complete, supporta squadre in preparazione, rende facoltativo il luogo e permette la modifica successiva delle rose. La migrazione non è stata eseguita o verificata su Supabase. L'app locale non richiede queste operazioni.
