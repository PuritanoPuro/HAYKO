import { align, createWidget, deleteWidget, setStatusBarVisible, widget } from '@zos/ui'
import { createCommand, enqueueCommand } from '../../shared/protocol'

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

const match = {
  id: 'demo-match-1',
  date: 'OGGI · 20:00',
  teamA: { name: 'FALCHI', color: C.lime, score: 0 },
  teamB: { name: 'LEONI', color: C.mint, score: 0 },
  playersA: [
    { id: 'a1', name: 'Andrea Rossi', color: 0xf57a4b },
    { id: 'a2', name: 'Matteo Bini', color: C.blue },
    { id: 'a3', name: 'Davide Sala', color: C.lime },
    { id: 'a4', name: 'Marco Riva', color: C.mint },
  ],
  playersB: [
    { id: 'b1', name: 'Luca Ferri', color: 0xffa733 },
    { id: 'b2', name: 'Paolo Neri', color: C.blue },
    { id: 'b3', name: 'Giorgio Villa', color: C.lime },
  ],
}

let screen = 'scheduled'
let scoringTeam = 'A'
let scorer = null
let assist = null
let keeper = null
let widgets = []

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
}

function rect(x, y, w, h, color, radius = 18) {
  add(widget.FILL_RECT, { x, y, w, h, color, radius })
}

function stroke(x, y, w, h, color, lineWidth = 2, radius = 18) {
  add(widget.STROKE_RECT, { x, y, w, h, color, line_width: lineWidth, radius })
}

function label(value, x, y, w, h, size = 20, color = C.chalk, center = false) {
  add(widget.TEXT, {
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
  label('‹', 14, 10, 26, 40, 34)
  label(title, 45, 12, 190, 36, 24)
  if (badge) {
    rect(244, 16, 60, 28, C.lime, 16)
    label(badge, 244, 16, 60, 28, 13, C.dark, true)
  }
}

function navigate(next) {
  screen = next
  render()
}

function scheduled() {
  label('Programmate', 16, 12, 288, 36, 25)
  label('LA PROSSIMA PARTITA', 18, 58, 284, 22, 12, C.muted)
  button('', 16, 88, 288, 142, () => navigate('detail'), {
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
  label('5 vs 5', 30, 194, 160, 22, 13, C.muted)
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
  enqueueCommand(createCommand('start_match', match.id))
  navigate('live')
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
  label('18:42', 120, 54, 80, 30, 16, C.lime, true)
  label(match.teamA.name, 20, 92, 120, 26, 16)
  label(match.teamB.name, 180, 92, 120, 26, 16, C.chalk, true)
  label(String(match.teamA.score), 32, 112, 90, 82, 64, C.chalk, true)
  label('—', 120, 112, 80, 82, 54, C.chalk, true)
  label(String(match.teamB.score), 198, 112, 90, 82, 64, C.chalk, true)
  goalButton('A', 16, match.teamA.color)
  goalButton('B', 168, match.teamB.color)
  rect(16, 328, 288, 40, C.surface, 18)
  label('Marco', 28, 328, 86, 40, 14)
  rect(119, 332, 82, 32, C.dark, 14)
  label('02:18', 119, 332, 82, 32, 18, C.lime, true)
  label('Luca', 208, 328, 82, 40, 14, C.chalk, true)
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
  selectionHeader('Chi ha segnato?', scoringTeam === 'A' ? match.teamA.name : match.teamB.name)
  const players = scoringTeam === 'A' ? match.playersA : match.playersB
  players.forEach((player, index) => playerRow(player, 88 + index * 56, () => {
    scorer = player
    navigate('assist')
  }))
}

function assistScreen() {
  selectionHeader('Chi ha fatto assist?', scorer ? scorer.name : '')
  const players = (scoringTeam === 'A' ? match.playersA : match.playersB).filter((player) => !scorer || player.id !== scorer.id)
  players.slice(0, 4).forEach((player, index) => playerRow(player, 82 + index * 56, () => {
    assist = player
    navigate('keeper')
  }))
  button('Nessun assist', 16, 316, 288, 48, () => {
    assist = null
    navigate('keeper')
  }, { color: C.surface, radius: 16, size: 16 })
}

function keeperScreen() {
  selectionHeader('Chi era in porta?', scoringTeam === 'A' ? match.teamB.name : match.teamA.name)
  const players = scoringTeam === 'A' ? match.playersB : match.playersA
  players.slice(0, 3).forEach((player, index) => playerRow(player, 82 + index * 62, () => {
    keeper = player
    navigate('confirm')
  }, index === 0, index === 0 ? 'Previsto dal giro' : ''))
}

function confirmScreen() {
  header('Conferma gol')
  label(scoringTeam === 'A' ? match.teamA.name : match.teamB.name, 18, 58, 284, 26, 15, C.lime, true)
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
  enqueueCommand(createCommand('end_match', match.id))
  navigate('finished')
}

function finishedScreen() {
  label('Partita terminata', 16, 24, 288, 38, 25, C.chalk, true)
  label(match.teamA.name, 20, 100, 110, 26, 16, C.chalk, true)
  label(match.teamB.name, 190, 100, 110, 26, 16, C.chalk, true)
  label(`${match.teamA.score} – ${match.teamB.score}`, 60, 132, 200, 82, 52, C.chalk, true)
  button('Torna alle programmate', 16, 276, 288, 62, () => navigate('scheduled'), {
    color: C.chalk,
    pressColor: C.muted,
    textColor: C.dark,
    radius: 20,
    size: 17,
  })
}

function confirmGoal() {
  const opponents = scoringTeam === 'A' ? match.playersB : match.playersA
  const selectedKeeper = keeper || opponents[0]
  enqueueCommand(createCommand('add_goal', match.id, {
    team: scoringTeam,
    scorerId: scorer && scorer.id,
    assistId: assist && assist.id,
    keeperId: selectedKeeper.id,
  }))
  if (scoringTeam === 'A') match.teamA.score += 1
  else match.teamB.score += 1
  navigate('live')
}

function render() {
  clear()
  rect(0, 0, 320, 380, C.bg, 0)
  if (screen === 'scheduled') scheduled()
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
    render()
  },
  onDestroy() { clear() },
})
