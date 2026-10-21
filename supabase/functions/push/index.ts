import { createClient } from 'npm:@supabase/supabase-js@2'
import { JWT } from 'npm:google-auth-library@10'

type PushRecord = {
  id: number
  user_id: string
  title: string
  body: string
  payload: Record<string, unknown>
}

type WebhookPayload = {
  type: 'INSERT'
  table: 'hayko_push_outbox'
  schema: 'public'
  record: PushRecord
}

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { 'content-type': 'application/json' },
})

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405)
  if (request.headers.get('x-hayko-webhook-secret') !== Deno.env.get('HAYKO_PUSH_WEBHOOK_SECRET')) {
    return json({ error: 'FORBIDDEN' }, 403)
  }

  const payload = await request.json() as WebhookPayload
  if (payload.type !== 'INSERT' || payload.table !== 'hayko_push_outbox') {
    return json({ error: 'INVALID_PAYLOAD' }, 400)
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )
  const record = payload.record
  const { data: devices, error: deviceError } = await supabase
    .from('hayko_push_devices')
    .select('installation_id, platform')
    .eq('user_id', record.user_id)
  if (deviceError) return json({ error: deviceError.message }, 500)

  if (!devices?.length) {
    await supabase.from('hayko_push_outbox').update({ sent_at: new Date().toISOString() }).eq('id', record.id)
    return json({ delivered: 0 })
  }

  const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!)
  const auth = new JWT({
    email: serviceAccount.client_email,
    key: serviceAccount.private_key,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })
  const credentials = await auth.authorize()
  const data = Object.fromEntries(
    Object.entries(record.payload ?? {}).map(([key, value]) => [key, String(value)]),
  )
  let delivered = 0
  const errors: string[] = []

  for (const device of devices) {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${credentials.access_token}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: device.installation_id,
            notification: { title: record.title, body: record.body },
            data,
            android: {
              priority: 'high',
              notification: { channel_id: 'league_access' },
            },
            apns: { payload: { aps: { sound: 'default' } } },
          },
        }),
      },
    )
    if (response.ok) {
      delivered++
      continue
    }
    const detail = await response.text()
    errors.push(`${response.status}: ${detail}`)
    if (response.status === 404) {
      await supabase.from('hayko_push_devices').delete().eq('installation_id', device.installation_id)
    }
  }

  await supabase.from('hayko_push_outbox').update({
    sent_at: errors.length === 0 ? new Date().toISOString() : null,
    last_error: errors.length === 0 ? null : errors.join('\n').slice(0, 4000),
  }).eq('id', record.id)

  return errors.length === 0
    ? json({ delivered })
    : json({ delivered, errors }, 502)
})
