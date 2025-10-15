import fs from 'fs'
import { finalizeEvent, nip19 } from 'nostr-tools'

const raw = JSON.parse(fs.readFileSync('unsigned.json','utf8'))
const unsigned = raw.event || raw
// Platzhalter-ID entfernen
delete unsigned.id

let skHex = process.env.NOSTR_SK_HEX
if (!skHex && process.env.NOSTR_NSEC) {
  const dec = nip19.decode(process.env.NOSTR_NSEC)
  skHex = Buffer.from(dec.data).toString('hex')
}
if (!skHex) throw new Error('Setze NOSTR_SK_HEX (hex) oder NOSTR_NSEC (nsec)')

const signed = finalizeEvent(unsigned, skHex)
fs.writeFileSync('signed.json', JSON.stringify(signed))
console.log('OK -> signed.json')
