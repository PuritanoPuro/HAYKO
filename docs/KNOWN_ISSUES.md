# Limiti conosciuti

Rilevati durante la revisione iniziale; questa riorganizzazione non ne modifica il comportamento.

1. **Conflitti della coda offline.** LeagueStore.flush si interrompe sulla prima operazione rifiutata. Un conflitto di revisione può bloccare anche operazioni di altre leghe. Riprova non offre un flusso di risoluzione. Serve una gestione esplicita dei conflitti che conservi le modifiche locali.
2. **Aggiornamento delle formazioni.** Cloud.refresh aggiorna le squadre di una partita esistente solo quando lo stato remoto è scheduled. Un client che riceve direttamente lo stato live può mantenere la formazione precedente.
3. **Validazione sul servizio reale.** I test locali non certificano SQL distribuito, email, deep link, notifiche native o comportamento con più dispositivi.
4. **Smartwatch.** Non è presente un'app nativa dedicata.
