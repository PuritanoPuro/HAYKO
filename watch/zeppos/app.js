import './shared/device-polyfill'
import { getPackageInfo } from '@zos/app'
import * as ble from '@zos/ble'
import { localStorage } from '@zos/storage'
import { MessageBuilder } from './shared/message'

function readOutbox() {
  try {
    return JSON.parse(localStorage.getItem('hayko-command-outbox') || '[]')
  } catch (_) {
    return []
  }
}

App({
  globalData: {
    messageBuilder: null,
    outbox: readOutbox(),
  },
  onCreate() {
    const { appId } = getPackageInfo()
    const messageBuilder = new MessageBuilder({
      appId,
      appDevicePort: 20,
      appSidePort: 0,
      ble,
    })
    this.globalData.messageBuilder = messageBuilder
    messageBuilder.connect()
  },
  onDestroy() {
    if (this.globalData.messageBuilder) this.globalData.messageBuilder.disConnect()
  },
})
