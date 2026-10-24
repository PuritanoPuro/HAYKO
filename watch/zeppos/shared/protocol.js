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
  return command
}

export function pendingCommands() {
  return [...getApp()._options.globalData.outbox]
}
