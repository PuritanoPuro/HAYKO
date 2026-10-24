import { align, createWidget, deleteWidget, prop, setStatusBarVisible, widget } from '@zos/ui'
import { setWakeUpRelaunch } from '@zos/display'
import { localStorage } from '@zos/storage'
import { acknowledgeCommands, createCommand, enqueueCommand, pendingCommands } from '../../shared/protocol'

const C = {
  bg: 0x071f18,
  surface: 0x10372d,
  surface2: 0x16473a,
  chalk: 0xf2f5ee,
  muted: 0xa9c2b6,
  lime: 0xe3f24a,
  mint: 0x69d4a5,
  blue: 0x7fb6dd,
  dark: 0x0e2b22,
  danger: 0xd94b45,
  dangerPressed: 0xb83d38,
}

const LIVE_STATE_KEY = 'hayko-live-match'
const SNAPSHOT_KEY = 'hayko-watch-snapshot'
const messageBuilder = getApp()._options.globalData.messageBuilder
let match = null
let syncState = 'loading'
let syncMessage = ''
let syncing = false
let syncAgain = false
let syncAgainKeepScreen = false
let liveTimer = null
let elapsedWidget = null
let keeperCountdownWidget = null
let keeperAWidget = null
let keeperBWidget = null
try {
  const value = localStorage.getItem(SNAPSHOT_KEY)
  if (value) match = normalizeSnapshot(JSON.parse(value))
} catch (_) {
  localStorage.removeItem(SNAPSHOT_KEY)
}
try {
  const value = JSON.parse(localStorage.getItem(LIVE_STATE_KEY) || 'null')
  if (match && value && value.live && value.matchId === match.id) {
    match.live = true
    match.status = 'live'
    match.teamA.score = value.scoreA || 0
    match.teamB.score = value.scoreB || 0
  }
} catch (_) {
  localStorage.removeItem(LIVE_STATE_KEY)
}

let screen = match && match.live ? 'live' : 'scheduled'
let scoringTeam = 0
let scorer = null
let assist = null
let keeper = null
let widgets = []

function formatDate(value) {
  if (!value) return 'Data e ora non indicate'
  const date = new Date(value)
  const day = String(date.getDate()).padStart(2, '0')
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const hour = String(date.getHours()).padStart(2, '0')
  const minute = String(date.getMinutes()).padStart(2, '0')
  return `${day}/${month} · ${hour}:${minute}`
}

function normalizeSnapshot(snapshot) {
  if (!snapshot || !snapshot.match) return null
  const raw = snapshot.match
  const players = snapshot.players || []
  const playerMap = {}
  players.forEach((player) => { playerMap[player.id] = player })
  const toPlayer = (id) => {
    const player = playerMap[id] || { id, name: 'Giocatore', color: C.muted }
    return { id: player.id, name: player.name, color: Number(player.color || C.muted) & 0xffffff }
  }
  const goals = (raw.goals || []).filter((goal) => !goal.voided)
  return {
    id: raw.id,
    live: raw.status === 'live',
    status: raw.status,
    date: formatDate(raw.scheduledAt),
    format: raw.format || 5,
    startedAt: raw.startedAt,
    competitionRules: Boolean(raw.competitionRules),
    keeperPlans: raw.keepers || [{ mode: 'manual' }, { mode: 'manual' }],
    teamA: {
      name: raw.names[0],
      color: Number((raw.teamColors || [C.lime])[0]) & 0xffffff,
      score: goals.filter((goal) => goal.team === 0).length,
    },
    teamB: {
      name: raw.names[1],
      color: Number((raw.teamColors || [C.lime, C.mint])[1]) & 0xffffff,
      score: goals.filter((goal) => goal.team === 1).length,
    },
    playersA: (raw.teams[0] || []).map(toPlayer),
    playersB: (raw.teams[1] || []).map(toPlayer),
  }
}

function applySnapshot(snapshot) {
  localStorage.setItem(SNAPSHOT_KEY, JSON.stringify(snapshot))
  match = normalizeSnapshot(snapshot)
  syncState = match ? 'ready' : 'empty'
  if (match && match.live) {
    screen = 'live'
    setWakeUpRelaunch({ relaunch: true })
  } else {
    screen = 'scheduled'
    setWakeUpRelaunch({ relaunch: false })
  }
  render()
}

function syncNow(keepScreen = false) {
  if (syncing) {
    syncAgain = true
    syncAgainKeepScreen = syncAgainKeepScreen || keepScreen
    return
  }
  if (!messageBuilder) {
    syncState = match ? 'ready' : 'error'
    syncMessage = 'Telefono non raggiungibile.'
    render()
    return
  }
  syncing = true
  const sentCommands = pendingCommands()
  messageBuilder.request({ method: 'SYNC', params: { commands: sentCommands } })
    .then((data) => {
      syncing = false
      const result = data.result || data
      acknowledgeCommands(result.ackIds || [])
      const stillPending = pendingCommands().length > 0
      if (result.status === 'unpaired') {
        syncState = 'unpaired'
        match = null
        render()
      } else if (result.status === 'ready') {
        if (keepScreen || stillPending) {
          syncState = 'ready'
        } else {
          applySnapshot(result.snapshot)
        }
      } else {
        syncState = match ? 'ready' : 'error'
        syncMessage = 'Sincronizzazione non disponibile.'
        render()
      }
      if (syncAgain || stillPending) {
        const nextKeepScreen = syncAgainKeepScreen
        syncAgain = false
        syncAgainKeepScreen = false
        syncNow(nextKeepScreen)
      }
    })
    .catch(() => {
      syncing = false
      syncState = match ? 'ready' : 'error'
      syncMessage = 'Avvicina telefono e orologio.'
      render()
      if (syncAgain) {
        const nextKeepScreen = syncAgainKeepScreen
        syncAgain = false
        syncAgainKeepScreen = false
        syncNow(nextKeepScreen)
      }
    })
}

function add(type, props) {
  const value = createWidget(type, props)
  // Decorative widgets sit above the button backgrounds. Disabling their
  // gesture handling lets the complete underlying container remain tappable.
  if (type !== widget.BUTTON) value.setEnable(false)
  widgets.push(value)
  return value
}

function clear() {
  widgets.forEach((value) => deleteWidget(value))
  widgets = []
  elapsedWidget = null
  keeperCountdownWidget = null
  keeperAWidget = null
  keeperBWidget = null
}

function rect(x, y, w, h, color, radius = 18) {
  add(widget.FILL_RECT, { x, y, w, h, color, radius })
}

function stroke(x, y, w, h, color, lineWidth = 2, radius = 18) {
  add(widget.STROKE_RECT, { x, y, w, h, color, line_width: lineWidth, radius })
}

function label(value, x, y, w, h, size = 20, color = C.chalk, center = false) {
  return add(widget.TEXT, {
    text: value,
    x,
    y,
    w,
    h,
    text_size: size,
    color,
    align_h: center ? align.CENTER_H : align.LEFT,
    align_v: align.CENTER_V,
  })
}

function button(value, x, y, w, h, onTap, options = {}) {
  add(widget.BUTTON, {
    x,
    y,
    w,
    h,
    text: value,
    text_size: options.size || 18,
    color: options.textColor || C.chalk,
    normal_color: options.color || C.surface,
    press_color: options.pressColor || C.surface2,
    radius: options.radius || 18,
    click_func: onTap,
  })
  if (options.border) stroke(x, y, w, h, options.border, options.borderWidth || 3, options.radius || 18)
}

function header(title, badge) {
  button('‹', 8, 8, 52, 48, goBack, {
    color: C.bg,
    pressColor: C.surface2,
    radius: 16,
    size: 36,
  })
  label(title, 68, 12, 168, 36, 23)
  if (badge) {
    rect(244, 16, 60, 28, C.lime, 16)
    label(badge, 244, 16, 60, 28, 13, C.dark, true)
  }
}

function goBack() {
  const previous = {
    detail: 'scheduled',
    live: 'scheduled',
    scorer: 'live',
    assist: 'scorer',
    keeper: 'assist',
    confirm: 'keeper',
    finish: 'live',
  }
  navigate(previous[screen] || 'scheduled')
}

function navigate(next) {
  screen = next
  render()
}

function persistLiveMatch() {
  localStorage.setItem(LIVE_STATE_KEY, JSON.stringify({
    live: true,
    matchId: match.id,
    scoreA: match.teamA.score,
    scoreB: match.teamB.score,
  }))
}

function connectionScreen(title, body, retry = false) {
  label(title, 16, 34, 288, 42, 25, C.chalk, true)
  rect(16, 104, 288, 144, C.surface, 20)
  label(body, 34, 126, 252, 92, 17, C.muted, true)
  if (retry) button('Riprova', 48, 280, 224, 58, () => {
    syncState = 'loading'
    render()
    syncNow()
  }, { color: C.chalk, pressColor: C.muted, textColor: C.dark, radius: 18 })
}

function unpairedScreen() {
  connectionScreen('Collega HAYKO', 'Apri le impostazioni di HAYKO nella Zepp App e inserisci il codice generato dall’app mobile.', true)
}

function emptyScreen() {
  connectionScreen('Nessuna partita', 'Non ci sono partite programmate o in corso create dal tuo account.', true)
}

function scheduled() {
  label('Programmate', 16, 12, 288, 36, 25)
  label(match.live ? 'PARTITA IN CORSO' : 'LA PROSSIMA PARTITA', 18, 58, 284, 22, 12, match.live ? C.lime : C.muted)
  button('', 16, 88, 288, 142, () => navigate(match.live ? 'live' : 'detail'), {
    color: C.surface,
    radius: 16,
  })
  label(match.teamA.name, 28, 104, 86, 30, 17, C.chalk, true)
  label(match.teamB.name, 206, 104, 86, 30, 17, C.chalk, true)
  rect(42, 140, 58, 6, match.teamA.color, 3)
  rect(220, 140, 58, 6, match.teamB.color, 3)
  label(String(match.teamA.score), 112, 102, 40, 42, 28, C.chalk, true)
  label('–', 152, 102, 16, 42, 20, C.muted, true)
  label(String(match.teamB.score), 168, 102, 40, 42, 28, C.chalk, true)
  label(match.date, 30, 166, 260, 26, 15, C.muted)
  label(`${match.format} vs ${match.format}`, 30, 194, 160, 22, 13, C.muted)
  label('›', 266, 188, 22, 30, 26, C.chalk, true)
}

function detail() {
  header('Partita')
  label(match.date, 55, 55, 210, 22, 13, C.muted, true)
  label(match.teamA.name, 22, 82, 125, 24, 16, C.chalk, true)
  label(match.teamB.name, 173, 82, 125, 24, 16, C.chalk, true)
  button('', 16, 116, 288, 236, startMatch, { color: C.surface, radius: 24 })
  add(widget.IMG, { x: 84, y: 134, w: 152, h: 152, src: 'whistle.png' })
  label('Inizia la partita', 34, 292, 252, 36, 22, C.chalk, true)
}

function startMatch() {
  match.live = true
  match.status = 'live'
  match.startedAt = new Date().toISOString()
  persistLiveMatch()
  setWakeUpRelaunch({ relaunch: true })
  enqueueCommand(createCommand('start_match', match.id))
  navigate('live')
  syncNow()
}

function elapsedText() {
  if (!match.startedAt) return '00:00'
  const total = Math.max(0, Math.floor((Date.now() - new Date(match.startedAt).getTime()) / 1000))
  const minutes = String(Math.floor(total / 60)).padStart(2, '0')
  const seconds = String(total % 60).padStart(2, '0')
  return `${minutes}:${seconds}`
}

function playersForTeam(team) {
  return team === 0 ? match.playersA : match.playersB
}

function predictedKeeper(team) {
  const plan = match.keeperPlans[team] || { mode: 'manual' }
  if (plan.mode === 'fixed') return plan.fixed
  if (plan.mode !== 'rotation' || !(plan.order || []).length || !match.startedAt) return null
  const seconds = Math.max(0, Math.floor((Date.now() - new Date(match.startedAt).getTime()) / 1000))
  const turn = Math.floor(seconds / (Math.max(1, plan.minutes || 5) * 60))
  return plan.order[turn % plan.order.length]
}

function playerName(team, id) {
  const found = playersForTeam(team).find((player) => player.id === id)
  return found ? found.name.split(' ')[0] : '—'
}

function keeperCountdown() {
  const plans = match.keeperPlans.filter((plan) => plan && plan.mode === 'rotation')
  if (!plans.length || !match.startedAt) return '--:--'
  const duration = Math.max(1, plans[0].minutes || 5) * 60
  const elapsed = Math.max(0, Math.floor((Date.now() - new Date(match.startedAt).getTime()) / 1000))
  const remaining = duration - (elapsed % duration)
  return `${String(Math.floor(remaining / 60)).padStart(2, '0')}:${String(remaining % 60).padStart(2, '0')}`
}

function live() {
  header('Partita')
  button('■', 258, 14, 46, 38, () => navigate('finish'), {
    color: C.danger,
    pressColor: C.dangerPressed,
    radius: 14,
    size: 18,
  })
  rect(120, 54, 80, 30, C.surface2, 18)
  elapsedWidget = label(elapsedText(), 120, 54, 80, 30, 16, C.lime, true)
  label(match.teamA.name, 20, 92, 120, 26, 16)
  label(match.teamB.name, 180, 92, 120, 26, 16, C.chalk, true)
  label(String(match.teamA.score), 32, 112, 90, 82, 64, C.chalk, true)
  label('—', 120, 112, 80, 82, 54, C.chalk, true)
  label(String(match.teamB.score), 198, 112, 90, 82, 64, C.chalk, true)
  goalButton(0, 16, match.teamA.color)
  goalButton(1, 168, match.teamB.color)
  rect(16, 328, 288, 40, C.surface, 18)
  keeperAWidget = label(playerName(0, predictedKeeper(0)), 28, 328, 86, 40, 14)
  rect(119, 332, 82, 32, C.dark, 14)
  keeperCountdownWidget = label(keeperCountdown(), 119, 332, 82, 32, 18, C.lime, true)
  keeperBWidget = label(playerName(1, predictedKeeper(1)), 208, 328, 82, 40, 14, C.chalk, true)
}

function refreshLiveTimers() {
  if (screen !== 'live' || !match || !match.live) return
  if (elapsedWidget) elapsedWidget.setProperty(prop.TEXT, elapsedText())
  if (keeperCountdownWidget) keeperCountdownWidget.setProperty(prop.TEXT, keeperCountdown())
  if (keeperAWidget) keeperAWidget.setProperty(prop.TEXT, playerName(0, predictedKeeper(0)))
  if (keeperBWidget) keeperBWidget.setProperty(prop.TEXT, playerName(1, predictedKeeper(1)))
}

function goalButton(team, x, color) {
  button('', x, 202, 136, 112, () => {
    scoringTeam = team
    scorer = null
    assist = null
    keeper = null
    navigate('scorer')
  }, { color: C.surface, border: color, borderWidth: 3, radius: 20 })
  add(widget.IMG, { x: x + 30, y: 220, src: 'ball.png' })
}

function playerRow(player, y, onTap, selected = false, note = '') {
  button('', 16, y, 288, 52, onTap, {
    color: C.surface,
    border: selected ? C.lime : C.surface2,
    borderWidth: selected ? 3 : 1,
    radius: 16,
  })
  rect(28, y + 10, 32, 32, player.color, 16)
  label(player.name.split(' ').map((part) => part[0]).join('').slice(0, 2), 28, y + 10, 32, 32, 11, C.dark, true)
  label(player.name, 72, y + (note ? 1 : 4), 194, note ? 29 : 44, 21)
  if (note) label(note, 72, y + 29, 194, 18, 11, C.lime)
  label('›', 276, y + 7, 18, 38, 22, C.muted, true)
}

function selectionHeader(title, subtitle) {
  header(title)
  label(subtitle, 18, 52, 284, 28, 15, C.muted)
}

function scorerScreen() {
  selectionHeader('Chi ha segnato?', scoringTeam === 0 ? match.teamA.name : match.teamB.name)
  const players = playersForTeam(scoringTeam)
  players.forEach((player, index) => playerRow(player, 88 + index * 56, () => {
    scorer = player
    navigate('assist')
  }))
}

function assistScreen() {
  selectionHeader('Chi ha fatto assist?', scorer ? scorer.name : '')
  const players = playersForTeam(scoringTeam).filter((player) => !scorer || player.id !== scorer.id)
  players.slice(0, 4).forEach((player, index) => playerRow(player, 82 + index * 56, () => {
    assist = player
    navigate(match.competitionRules ? 'confirm' : 'keeper')
  }))
  button('Nessun assist', 16, 316, 288, 48, () => {
    assist = null
    navigate(match.competitionRules ? 'confirm' : 'keeper')
  }, { color: C.surface, radius: 16, size: 16 })
}

function keeperScreen() {
  const defendingTeam = 1 - scoringTeam
  selectionHeader('Chi era in porta?', defendingTeam === 0 ? match.teamA.name : match.teamB.name)
  const expected = predictedKeeper(defendingTeam)
  const players = [...playersForTeam(defendingTeam)].sort((a, b) => a.id === expected ? -1 : b.id === expected ? 1 : 0)
  players.slice(0, 5).forEach((player, index) => playerRow(player, 82 + index * 56, () => {
    keeper = player
    navigate('confirm')
  }, player.id === expected, player.id === expected ? 'Previsto dal giro' : ''))
}

function confirmScreen() {
  header('Conferma gol')
  label(scoringTeam === 0 ? match.teamA.name : match.teamB.name, 18, 58, 284, 26, 15, C.lime, true)
  rect(16, 94, 288, 174, C.surface, 20)
  summaryRow('ball-small.png', scorer ? scorer.name : '—', 103)
  summaryRow('boot.png', assist ? assist.name : 'Nessun assist', 159)
  summaryRow('glove.png', keeper ? keeper.name : '—', 215)
  button('Conferma gol', 16, 286, 288, 66, confirmGoal, {
    color: C.chalk,
    pressColor: C.muted,
    textColor: C.dark,
    radius: 20,
    size: 20,
  })
}

function summaryRow(icon, value, y) {
  add(widget.IMG, { x: 30, y, src: icon })
  label(value, 82, y, 202, 40, 20)
}

function finishScreen() {
  header('Termina partita')
  label('Vuoi terminare la partita?', 20, 70, 280, 34, 20, C.chalk, true)
  label(match.teamA.name, 20, 122, 110, 26, 16, C.chalk, true)
  label(match.teamB.name, 190, 122, 110, 26, 16, C.chalk, true)
  label(`${match.teamA.score} – ${match.teamB.score}`, 70, 150, 180, 64, 44, C.chalk, true)
  button('Termina partita', 16, 238, 288, 58, endMatch, {
    color: C.danger,
    pressColor: C.dangerPressed,
    radius: 18,
    size: 19,
  })
  button('Annulla', 16, 308, 288, 52, () => navigate('live'), {
    color: C.surface,
    pressColor: C.surface2,
    radius: 18,
    size: 18,
  })
}

function endMatch() {
  match.live = false
  match.status = 'finished'
  localStorage.removeItem(LIVE_STATE_KEY)
  setWakeUpRelaunch({ relaunch: false })
  enqueueCommand(createCommand('end_match', match.id))
  navigate('finished')
  syncNow(true)
}

function finishedScreen() {
  label('Partita terminata', 16, 24, 288, 38, 25, C.chalk, true)
  label(match.teamA.name, 20, 100, 110, 26, 16, C.chalk, true)
  label(match.teamB.name, 190, 100, 110, 26, 16, C.chalk, true)
  label(`${match.teamA.score} – ${match.teamB.score}`, 60, 132, 200, 82, 52, C.chalk, true)
  button('Torna alle programmate', 16, 276, 288, 62, () => {
    match = null
    syncState = 'loading'
    screen = 'scheduled'
    render()
    syncNow()
  }, {
    color: C.chalk,
    pressColor: C.muted,
    textColor: C.dark,
    radius: 20,
    size: 17,
  })
}

function confirmGoal() {
  const opponents = playersForTeam(1 - scoringTeam)
  const selectedKeeper = keeper || opponents[0]
  enqueueCommand(createCommand('add_goal', match.id, {
    team: scoringTeam,
    scorerId: scorer && scorer.id,
    assistId: assist && assist.id,
    keeperId: match.competitionRules ? null : selectedKeeper.id,
  }))
  if (scoringTeam === 0) match.teamA.score += 1
  else match.teamB.score += 1
  persistLiveMatch()
  navigate('live')
  syncNow()
}

function render() {
  clear()
  rect(0, 0, 320, 380, C.bg, 0)
  if (!match) {
    if (syncState === 'unpaired') unpairedScreen()
    else if (syncState === 'empty') emptyScreen()
    else if (syncState === 'error') connectionScreen('Connessione', syncMessage || 'Sincronizzazione non disponibile.', true)
    else connectionScreen('HAYKO', 'Sincronizzazione delle partite in corso…')
  } else if (screen === 'scheduled') scheduled()
  else if (screen === 'detail') detail()
  else if (screen === 'live') live()
  else if (screen === 'scorer') scorerScreen()
  else if (screen === 'assist') assistScreen()
  else if (screen === 'keeper') keeperScreen()
  else if (screen === 'confirm') confirmScreen()
  else if (screen === 'finish') finishScreen()
  else finishedScreen()
}

Page({
  build() {
    setStatusBarVisible(false)
    syncState = match ? 'ready' : 'loading'
    setWakeUpRelaunch({ relaunch: Boolean(match && match.live) })
    render()
    liveTimer = setInterval(refreshLiveTimers, 1000)
    syncNow()
  },
  onResume() {
    if (match && match.live && screen !== 'live') {
      screen = 'live'
      render()
    }
    syncNow()
  },
  onDestroy() {
    if (liveTimer) clearInterval(liveTimer)
    liveTimer = null
    clear()
  },
})
