const CODE_KEY = 'haykoPairingCode'
const STATUS_KEY = 'haykoPairingStatus'

function statusValue(props) {
  try {
    return JSON.parse(props.settingsStorage.getItem(STATUS_KEY) || '{}')
  } catch (_) {
    return {}
  }
}

AppSettingsPage({
  build(props) {
    const status = statusValue(props)
    const statusText = status.state === 'paired'
      ? 'Smartwatch collegato a HAYKO.'
      : status.state === 'busy'
        ? 'Collegamento in corso…'
        : status.state === 'error'
          ? (status.message || 'Collegamento non riuscito.')
          : 'Genera il codice nell’app HAYKO e inseriscilo qui.'

    return View({ style: { padding: '18px 20px', background: '#071f18' } }, [
      View({ style: {
        padding: '18px',
        borderRadius: '16px',
        background: '#10372d',
        color: '#f2f5ee',
      } }, [
        View({ style: { fontSize: '20px', fontWeight: 'bold', marginBottom: '8px' } }, ['Collega HAYKO']),
        View({ style: { fontSize: '14px', lineHeight: '20px', color: '#a9c2b6', marginBottom: '16px' } }, [statusText]),
        TextInput({
          label: 'Codice a 6 cifre',
          value: '',
          maxLength: 6,
          onChange: (value) => {
            const code = String(value || '').replace(/[^0-9]/g, '').slice(0, 6)
            if (code.length === 6) props.settingsStorage.setItem(CODE_KEY, code)
          },
        }),
      ]),
    ])
  },
})
