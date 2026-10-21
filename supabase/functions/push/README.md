# HAYKO push

La funzione riceve gli inserimenti di `public.hayko_push_outbox` tramite un
Database Webhook Supabase e invia le notifiche con FCM HTTP v1.

Segreti richiesti:

- `FIREBASE_SERVICE_ACCOUNT`: JSON completo del service account Firebase.
- `HAYKO_PUSH_WEBHOOK_SECRET`: valore casuale condiviso con l'header
  `x-hayko-webhook-secret` del Database Webhook.

Distribuzione:

```sh
supabase functions deploy push --no-verify-jwt
```

Il webhook deve osservare `INSERT` su `public.hayko_push_outbox`, usare `POST`
e includere l'header segreto. Le variabili `SUPABASE_URL` e
`SUPABASE_SERVICE_ROLE_KEY` sono fornite automaticamente alla funzione.
