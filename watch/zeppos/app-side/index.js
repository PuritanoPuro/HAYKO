import { MessageBuilder } from '../shared/message-side'
import { SUPABASE_KEY, SUPABASE_URL } from './config'

const messageBuilder = new MessageBuilder()
const TOKEN_KEY = 'haykoDeviceToken'
const STATUS_KEY = 'haykoPairingStatus'

function bodyOf(response) {
  return typeof response.body === 'string' ? JSON.parse(response.body) : response.body
}

async function rpc(name, body) {
  const response = await fetch({
    url: `${SUPABASE_URL}/rest/v1/rpc/${name}`,
    method: 'POST',
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  })
  const value = bodyOf(response)
  if (value && (value.message || value.error)) throw new Error(value.message || value.error)
  return value
}

async function pair(code) {
  settings.settingsStorage.setItem(STATUS_KEY, JSON.stringify({ state: 'busy' }))
  try {
    const value = await rpc('hayko_watch_redeem', {
      p_code: code,
      p_label: 'Amazfit Bip 5',
    })
    settings.settingsStorage.setItem(TOKEN_KEY, value.token)
    settings.settingsStorage.setItem(STATUS_KEY, JSON.stringify({
      state: 'paired',
      deviceId: value.deviceId,
    }))
  } catch (_) {
    settings.settingsStorage.setItem(STATUS_KEY, JSON.stringify({
      state: 'error',
      message: 'Codice non valido, scaduto o già utilizzato.',
    }))
  }
}

async function synchronize(commands) {
  const token = settings.settingsStorage.getItem(TOKEN_KEY)
  if (!token) return { status: 'unpaired', ackIds: [] }
  const ackIds = []
  const errors = []
  for (const command of commands || []) {
    try {
      await rpc('hayko_watch_command', { p_token: token, p_command: command })
      ackIds.push(command.id)
    } catch (error) {
      errors.push({ id: command.id, message: String(error.message || error) })
    }
  }
  const snapshot = await rpc('hayko_watch_snapshot', { p_token: token })
  return { status: 'ready', snapshot, ackIds, errors }
}

AppSideService({
  onInit() {
    messageBuilder.listen(() => {})
    settings.settingsStorage.addListener('change', ({ key, newValue }) => {
      if (key === 'haykoPairingCode' && /^[0-9]{6}$/.test(String(newValue || ''))) {
        pair(String(newValue))
      }
    })
    messageBuilder.on('request', async (ctx) => {
      const request = messageBuilder.buf2Json(ctx.request.payload)
      if (request.method !== 'SYNC') return
      try {
        const result = await synchronize((request.params || {}).commands || [])
        ctx.response({ data: { result } })
      } catch (error) {
        ctx.response({ data: { result: {
          status: 'error',
          message: String(error.message || error),
          ackIds: [],
        } } })
      }
    })
  },
  onRun() {},
  onDestroy() {},
})
