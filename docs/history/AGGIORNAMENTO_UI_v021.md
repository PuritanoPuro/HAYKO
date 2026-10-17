# UI v0.2.1 — 12 ottobre 2026

Questa nota aggiorna i comportamenti di AGGIORNAMENTO_v02.md.

- Formazioni: conteggio e Conferma in un header fisso sopra la lista; rimane
  il riepilogo conferma/modifica. L'header non scorre insieme ai giocatori.
- Giro portieri: contenitori riordinabili con pressione prolungata e
  trascinamento, senza frecce. Il riordino viene salvato nella configurazione
  della partita; usa onReorderItem del Flutter installato sul Mac (3.47.7).
- Statistiche: ordine decrescente delle PG per il filtro selezionato; a parità
  ordine alfabetico. Le classifiche continuano a usare la media a partita.
- Cronometro: calcolato da startedAt, non si azzera alla riapertura. Alla fine
  usa finishedAt e resta fermo. Formato MM:SS, HH:MM:SS oltre un'ora.
- Portieri live: corrente, successivo e countdown MM:SS. Tolti giro completo
  e testo “Prossimo cambio tra”. La selezione nel wizard gol rimane disponibile
  per portieri a rotazione, perché il turno reale può differire da quello previsto.
- Partite: tab Programmate (blu), In corso (verde), Terminate (grigio/lilla),
  header e bordo delle schede coerenti col colore. Dot sulla tab In corso se
  esiste un evento live. Entrando nella lega si apre In corso se presente;
  tornando da un match si seleziona la tab corrispondente al suo stato.

Patch incrementale: aggiorna solo sorgenti UI, helper di presentazione, questa
nota e 5 test nuovi. Non modifica dipendenze, backend, host nativi o dati.
Verificata l'applicazione della patch, la riapplicazione senza doppie modifiche
e il rifiuto di file alterati manualmente. Flutter analyze, i 19 test totali
e le prove visive devono essere eseguiti sul Mac; non c'è SDK Flutter qui.
