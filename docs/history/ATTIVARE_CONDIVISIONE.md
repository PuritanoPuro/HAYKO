# Attivazione social — operazione successiva all'aggiornamento locale

Non è stato creato un progetto Supabase né distribuito un server.
Per Filippo: prima proviamo l'aggiornamento locale sul simulatore; i passaggi
seguenti servono quando attiveremo insieme l'accesso da più telefoni.

1. Creare un progetto Supabase di test nel proprio account.
2. Nel SQL Editor eseguire backend/social_v02.sql, una sola volta sul progetto
   nuovo. Non serve prima schema.sql: quello rimane la proposta v0.1.
3. Impostare Auth email con registrazione abilitata. Nel template “Magic Link”
   inviare il codice tramite la variabile {{ .Token }}. La UI usa OTP email,
   non un link di callback; mantenere una scadenza breve e limiti di invio.
4. Reperire Project URL e la chiave publishable/anon. NON service_role o secret.
5. Creare sul Mac una copia mobile/cloud-config.example.json chiamata
   cloud-config.json, inserendo URL e chiave pubblica. Poi avviare dalla cartella
   mobile con:

```sh
flutter run --dart-define-from-file=cloud-config.json -d 673792EC-ABD0-4D81-B8F8-E03100C84FEF
```

Il simulatore indicato è quello già usato; se cambia controllare flutter devices.
La config non contiene password: la protezione è nel server, non nel segreto
della chiave anon. Anche così non inserire chiavi amministrative nell'app.

6. Aprire “Leghe condivise e inviti”, richiedere OTP email, verificare codice,
   creare una lega, associare il proprio giocatore e aggiungere gli ospiti.
7. Da “Membri e inviti”, copiare l'invito. Un secondo utente su un secondo
   dispositivo configurato accede, sceglie “Entra con un invito” e lo incolla.
8. Il secondo utente seleziona il proprio nome libero o lo aggiunge; il presidente
   può promuoverlo admin. Provare creazione eventi e rifiuto delle modifiche
   agli eventi altrui. I badge si vedono nell'elenco Giocatori.
9. Eseguire test_social_v02.sql solo su progetto DI TEST: inserisce utenti
   fixture e annulla la transazione finale. Non è stato eseguito qui.

Prima di invitare il gruppo reale: provare inviti scaduti/revocati, stesso
giocatore reclamato simultaneamente, revisione superata, membro non admin,
presidente che tenta un gol su evento altrui e logout. Configurare SMTP e
limiti del progetto in base alla beta. Le leghe locali non vengono importate
automaticamente, e la release non contiene ancora rete offline o app watch.
