import { localStorage } from '@zos/storage'

export const COMMAND_VERSION = 1

let sequence = 0

export function createCommand(type, matchId, payload = {}) {
  sequence += 1
  return {
    version: COMMAND_VERSION,
    id: `${matchId}-${Date.now()}-${sequence}`,
    type,
    matchId,
    createdAt: new Date().toISOString(),
    payload,
  }
}

export function enqueueCommand(command) {
  const queue = getApp()._options.globalData.outbox
  if (!queue.some((item) => item.id === command.id)) queue.push(command)
  persist(queue)
  return command
}

export function pendingCommands() {
  return [...getApp()._options.globalData.outbox]
}

export function acknowledgeCommands(ids = []) {
  if (!ids.length) return
  const app = getApp()._options.globalData
  app.outbox = app.outbox.filter((item) => !ids.includes(item.id))
  persist(app.outbox)
}

function persist(queue) {
  localStorage.setItem('hayko-command-outbox', JSON.stringify(queue))
}
