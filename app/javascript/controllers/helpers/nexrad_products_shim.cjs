// Browser-safe product registry for nexrad-level-3-data (avoids fs.readdirSync).
// Product 153 (N0B/NAB/N1B) shares the digital-reflectivity description layout with 94.
const { RandomAccessFile } = require("nexrad-level-3-data/src/randomaccessfile")

const halfwords30_53 = (data) => {
  const raf = new RandomAccessFile(data)
  return {
    elevationAngle: raf.readShort() / 10,
    plot: {
      minimumDataValue: raf.readShort() / 10,
      dataIncrement: raf.readShort() / 10,
      dataLevels: raf.readShort(),
    },
    dependent34_46: raf.read(26),
    maxReflectivity: raf.readShort(),
    dependent48_49: raf.read(4),
    ...deltaTime(raf.readShort()),
    compressionMethod: raf.readShort(),
    uncompressedProductSize: (raf.readUShort() << 16) + raf.readUShort(),
  }
}

const deltaTime = (value) => ({
  deltaTime: (value & 0xffe0) >> 5,
  nonSupplementalScan: (value & 0x001f) === 0,
  sailsScan: (value & 0x001f) === 1,
  mrleScan: (value & 0x001f) === 2,
})

const digitalReflectivity = {
  abbreviation: ["NXQ", "NYQ", "NZQ", "N0Q", "NAQ", "N1Q", "NBQ", "N2Q", "N3Q"],
  description: "Digital Base Reflectivity",
  productDescription: { halfwords30_53 },
}

const superResReflectivity = {
  abbreviation: ["N0B", "NAB", "N1B", "NBB", "N2B", "N3B", "NZB"],
  description: "Super Res Digital Base Reflectivity",
  productDescription: { halfwords30_53 },
}

const products = {
  94: { code: 94, ...digitalReflectivity },
  153: { code: 153, ...superResReflectivity },
}

const productAbbreviations = [
  ...digitalReflectivity.abbreviation,
  ...superResReflectivity.abbreviation,
]

module.exports = {
  products,
  productAbbreviations,
}
