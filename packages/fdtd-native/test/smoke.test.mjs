import test from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)

test('native addon exports FDTD classes', () => {
  let native
  try {
    native = require('../index.js')
  } catch (err) {
    if (process.env.FDTD_SKIP_NATIVE === '1') return
    throw err
  }
  assert.equal(typeof native.Fdtd1D, 'function')
  assert.equal(typeof native.Fdtd2D, 'function')
  assert.equal(typeof native.Fdtd2DTFSF, 'function')

  const s = new native.Fdtd1D({
    omega: 1.0,
    tau: 8.0,
    materialVector: new Array(50).fill(0),
    eps: [1],
    mu: [1],
    sigma: [0],
    srcPosition: [0.3],
  })
  const frame = s.getNextTimeLayer()
  assert.ok(frame.dataEx.length > 0)
  assert.ok(Number.isFinite(frame.maxEx))
})
