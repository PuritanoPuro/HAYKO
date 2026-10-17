HAYKO - decisioni account, 16 ottobre 2026

Confermate dall'utente:
- Accesso obbligatorio, email/password. Nome, cognome, nickname ed email richiesti.
- Solo il proprio profilo e' consultabile. Nessuna classifica globale nel profilo.
- Nome suggerito in lega: solo nome, modificabile indipendentemente dal profilo.
- Nome e colore del proprio giocatore modificabili in lega amatoriale.
- Invito -> richiesta -> approvazione presidente/admin -> scelta giocatore -> conferma utente.
- Chi crea l'evento ne detiene il controllo esclusivo. Nessun controllo condiviso.
- Admin: gestione giocatori, squadre, calendario, nome/colori lega, approvazioni.
- Eliminazione lega e nomina admin riservate al presidente.
- Statistiche e storico restano quando si rimuove l'accesso di un membro.
- Account e leghe su piu' dispositivi; supporto offline durante le partite.
- Suoni/vibrazioni/notifiche nelle impostazioni dell'app, non nel profilo.
- Nessuna migrazione automatica delle leghe di prova del simulatore.
- Test smartwatch disponibili: Apple Watch e Amazfit Bip 5. Wear OS resta nella roadmap.

Implementato in questa fase:
Accesso/registrazione/conferma email/recupero password, profilo privato,
impostazioni app, leghe cloud con cache per account e coda locale ordinata,
richieste di ingresso, conferma del giocatore, permessi sul server.

Da sviluppare e verificare in fasi successive:
Apple/Google login; SMTP per email a utenti esterni; link HTTPS universali e
fallback per chi non ha l'app (ora schema hayko:// con app installata);
editor per correggere partite terminate; risoluzione guidata dei conflitti
tra modifiche offline di piu' dispositivi; restyling delle altre schermate;
integrazioni smartwatch, da verificare per piattaforma; splash e icone native.

Figma usato: CvfPybiKhi6bDSN1yl0aXC, profilo 48:226, impostazioni 48:255,
accesso 5:157. L'accesso email/password e i campi nome/cognome aggiornano il
vecchio prototipo con le decisioni del 16/10. UI da validare su Device Hub.
