/**
 * Binary field-frame format (little-endian).
 *
 * Layout:
 *   magic   u32  = 0x46445444 ('FDTD')
 *   version u16  = 1
 *   kind    u16  = 1 (1D) | 2 (2D / TFSF)
 *   step    u32
 *   rows    u32  (1 for 1D)
 *   cols    u32
 *   min     f64
 *   max     f64
 *   pad     u32  (reserved, 0) — pads header to 40 bytes for f64 alignment
 *   values  f64[rows * cols]   // 1D: plotted channel; 2D: scalar field
 *
 * dataX / dataY index axes are reconstructed by the decoder (0..cols-1 / 0..rows-1).
 */

export const BINARY_FRAME_MAGIC = 0x46445444 // 'FDTD'
export const BINARY_FRAME_VERSION = 1

export const BinaryKind = {
  OneD: 1,
  TwoD: 2,
} as const
export type BinaryKindCode = (typeof BinaryKind)[keyof typeof BinaryKind]

/** 40 bytes — multiple of 8 so Float64Array views are aligned. */
const HEADER_BYTES = 40

export type DecodedBinaryFrame = {
  kind: '1d' | '2d'
  step: number
  row: number
  col: number
  min: number
  max: number
  /** Primary field channel (1D: Y; 2D: dataVal). */
  values: Float64Array
  dataX: number[]
  dataY: number[]
  dataVal?: number[]
}

export type EncodeBinaryInput = {
  kind: '1d' | '2d'
  step: number
  rows: number
  cols: number
  min: number
  max: number
  /** Length must be rows*cols (2D) or cols (1D with rows=1). */
  values: ArrayLike<number>
}

export type BinaryInput = ArrayBuffer | ArrayBufferView

function assertFinite(n: number, label: string) {
  if (!Number.isFinite(n)) throw new Error(`binary frame: ${label} is not finite`)
}

/** Encode a field frame to an ArrayBuffer (Node and browser). */
export function encodeBinaryFrame(input: EncodeBinaryInput): ArrayBuffer {
  const rows = input.kind === '1d' ? 1 : input.rows
  const cols = input.cols
  const count = rows * cols
  if (input.values.length !== count) {
    throw new Error(
      `binary frame: expected ${count} values, got ${input.values.length}`,
    )
  }
  assertFinite(input.min, 'min')
  assertFinite(input.max, 'max')

  const buf = new ArrayBuffer(HEADER_BYTES + count * 8)
  const view = new DataView(buf)
  let o = 0
  view.setUint32(o, BINARY_FRAME_MAGIC, true)
  o += 4
  view.setUint16(o, BINARY_FRAME_VERSION, true)
  o += 2
  view.setUint16(o, input.kind === '1d' ? BinaryKind.OneD : BinaryKind.TwoD, true)
  o += 2
  view.setUint32(o, input.step >>> 0, true)
  o += 4
  view.setUint32(o, rows >>> 0, true)
  o += 4
  view.setUint32(o, cols >>> 0, true)
  o += 4
  view.setFloat64(o, input.min, true)
  o += 8
  view.setFloat64(o, input.max, true)
  o += 8
  view.setUint32(o, 0, true) // reserved pad
  o += 4

  const f64 = new Float64Array(buf, HEADER_BYTES, count)
  for (let i = 0; i < count; i++) f64[i] = Number(input.values[i])

  return buf
}

function toArrayBuffer(data: BinaryInput): ArrayBuffer {
  if (data instanceof ArrayBuffer) return data
  const copy = new Uint8Array(data.byteLength)
  copy.set(new Uint8Array(data.buffer, data.byteOffset, data.byteLength))
  return copy.buffer
}

/** True if buffer starts with FDTD magic (cheap peek). */
export function isBinaryFrame(data: BinaryInput): boolean {
  const ab = toArrayBuffer(data)
  if (ab.byteLength < 4) return false
  return new DataView(ab).getUint32(0, true) === BINARY_FRAME_MAGIC
}

/** Decode a binary field frame; throws on bad magic/version/size. */
export function decodeBinaryFrame(data: BinaryInput): DecodedBinaryFrame {
  const ab = toArrayBuffer(data)
  if (ab.byteLength < HEADER_BYTES) {
    throw new Error('binary frame: truncated header')
  }
  const view = new DataView(ab)
  let o = 0
  const magic = view.getUint32(o, true)
  o += 4
  if (magic !== BINARY_FRAME_MAGIC) {
    throw new Error(`binary frame: bad magic 0x${magic.toString(16)}`)
  }
  const version = view.getUint16(o, true)
  o += 2
  if (version !== BINARY_FRAME_VERSION) {
    throw new Error(`binary frame: unsupported version ${version}`)
  }
  const kindCode = view.getUint16(o, true)
  o += 2
  const step = view.getUint32(o, true)
  o += 4
  const rows = view.getUint32(o, true)
  o += 4
  const cols = view.getUint32(o, true)
  o += 4
  const min = view.getFloat64(o, true)
  o += 8
  const max = view.getFloat64(o, true)
  o += 8
  o += 4 // reserved pad

  const count = rows * cols
  const need = HEADER_BYTES + count * 8
  if (ab.byteLength < need) {
    throw new Error(`binary frame: truncated values (need ${need}, got ${ab.byteLength})`)
  }
  const values = new Float64Array(ab, HEADER_BYTES, count).slice()

  if (kindCode === BinaryKind.OneD) {
    const dataX = Array.from({ length: cols }, (_, i) => i)
    const dataY = Array.from(values)
    return {
      kind: '1d',
      step,
      row: 1,
      col: cols,
      min,
      max,
      values,
      dataX,
      dataY,
    }
  }
  if (kindCode === BinaryKind.TwoD) {
    const dataX = Array.from({ length: cols }, (_, i) => i)
    const dataY = Array.from({ length: rows }, (_, j) => j)
    const dataVal = Array.from(values)
    return {
      kind: '2d',
      step,
      row: rows,
      col: cols,
      min,
      max,
      values,
      dataX,
      dataY,
      dataVal,
    }
  }
  throw new Error(`binary frame: unknown kind ${kindCode}`)
}
