import test from 'node:test'
import assert from 'node:assert/strict'
import {
  BINARY_FRAME_MAGIC,
  decodeBinaryFrame,
  encodeBinaryFrame,
  isBinaryFrame,
} from '../dist/index.js'

test('encode/decode 1D round-trip', () => {
  const values = Float64Array.from([0.1, -0.2, 0.3, 0.4])
  const buf = encodeBinaryFrame({
    kind: '1d',
    step: 42,
    rows: 1,
    cols: 4,
    min: -0.2,
    max: 0.4,
    values,
  })
  assert.equal(isBinaryFrame(buf), true)
  assert.equal(new DataView(buf).getUint32(0, true), BINARY_FRAME_MAGIC)
  const d = decodeBinaryFrame(buf)
  assert.equal(d.kind, '1d')
  assert.equal(d.step, 42)
  assert.equal(d.col, 4)
  assert.deepEqual(d.dataY, [...values])
  assert.deepEqual(d.dataX, [0, 1, 2, 3])
})

test('encode/decode 2D round-trip', () => {
  const values = Float64Array.from([1, 2, 3, 4, 5, 6])
  const buf = encodeBinaryFrame({
    kind: '2d',
    step: 7,
    rows: 2,
    cols: 3,
    min: 1,
    max: 6,
    values,
  })
  const d = decodeBinaryFrame(buf)
  assert.equal(d.kind, '2d')
  assert.equal(d.row, 2)
  assert.equal(d.col, 3)
  assert.deepEqual(d.dataVal, [...values])
})
