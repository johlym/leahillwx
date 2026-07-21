// Browser-safe packet registry for nexrad-level-3-data (avoids fs.readdirSync).
// Super-res reflectivity (N0B/NAB/N1B) uses Digital Radial Data Array packet 16.
const packet16 = require("nexrad-level-3-data/src/packets/10")

const packets = {
  [packet16.code]: packet16,
}

const parser = (raf, productDescription) => {
  const packetCode = raf.readUShort()
  raf.skip(-2)
  const packetCodeHex = packetCode.toString(16).padStart(4, "0")
  const packet = packets[packetCode]
  if (!packet) throw new Error(`Unsupported packet code 0x${packetCodeHex}`)
  return packet.parser(raf, productDescription)
}

module.exports = {
  packets,
  parser,
}
