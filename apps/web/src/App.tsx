import { useMemo, useState } from 'react'
import type { Material, SimType } from '@fdtd-online/protocol'
import { defaultMatrix, MatrixEditor } from './components/MatrixEditor'
import { FieldViz } from './components/FieldViz'
import { useFdtdSocket } from './hooks/useFdtdSocket'

const MATERIALS: Material[] = [
  { id: 0, eps: 1, mu: 1, sigma: 0 },
  { id: 1, eps: 4, mu: 1, sigma: 0 },
  { id: 2, eps: 3, mu: 1, sigma: 1e6 },
]

export function App() {
  const { status, frame, lastError, start, pause, continue: cont, stop } =
    useFdtdSocket()
  const [simType, setSimType] = useState<SimType>('1D')
  const [omega, setOmega] = useState(1.0)
  const [tau, setTau] = useState(8)
  const [lambda, setLambda] = useState(50)
  const [beamsize, setBeamsize] = useState(20)
  const [srcX, setSrcX] = useState(0.3)
  const [srcY, setSrcY] = useState(0.5)
  const [srcType, setSrcType] = useState(1)
  const [dataToReturn, setDataToReturn] = useState(0)
  const [matrixSize] = useState(16)
  const [matrix, setMatrix] = useState(() => defaultMatrix(16))
  const [activeMaterial, setActiveMaterial] = useState(1)

  const condition = useMemo(
    (): [number, number] =>
      simType === '1D' ? [omega, tau] : [lambda, beamsize],
    [simType, omega, tau, lambda, beamsize],
  )

  const onStart = () => {
    start({
      type: simType,
      condition,
      materialMatrix: matrix,
      materials: MATERIALS,
      srcPositionRelative: [{ x: srcX, y: srcY }],
      srcType,
      dataToReturn,
    })
  }

  return (
    <div className="app-shell">
      <h1 className="brand">Nanophotonics with FDTD</h1>
      <p className="tagline">
        Live 1D / 2D / TF–SF electromagnetic simulation — Rust physics core over
        WebSocket.
      </p>

      <div className="layout">
        <aside className="panel">
          <h2>Setup</h2>
          <div className="field">
            <label>Simulation</label>
            <select
              value={simType}
              onChange={(e) => setSimType(e.target.value as SimType)}
            >
              <option value="1D">1D PML</option>
              <option value="2D">2D TE_z PML</option>
              <option value="2D_TFSF">2D UPML + TF/SF</option>
            </select>
          </div>

          {simType === '1D' ? (
            <>
              <div className="field">
                <label>ω (source)</label>
                <input
                  type="number"
                  step="0.1"
                  value={omega}
                  onChange={(e) => setOmega(Number(e.target.value))}
                />
              </div>
              <div className="field">
                <label>τ (pulse width)</label>
                <input
                  type="number"
                  step="0.5"
                  value={tau}
                  onChange={(e) => setTau(Number(e.target.value))}
                />
              </div>
            </>
          ) : (
            <>
              <div className="field">
                <label>λ (UI scale)</label>
                <input
                  type="number"
                  value={lambda}
                  onChange={(e) => setLambda(Number(e.target.value))}
                />
              </div>
              <div className="field">
                <label>Beam size</label>
                <input
                  type="number"
                  value={beamsize}
                  onChange={(e) => setBeamsize(Number(e.target.value))}
                />
              </div>
              <div className="field">
                <label>Source type</label>
                <select
                  value={srcType}
                  onChange={(e) => setSrcType(Number(e.target.value))}
                >
                  <option value={1}>Soft sinusoid</option>
                  <option value={2}>Hard Gaussian×sin</option>
                </select>
              </div>
              <div className="field">
                <label>Field channel</label>
                <select
                  value={dataToReturn}
                  onChange={(e) => setDataToReturn(Number(e.target.value))}
                >
                  <option value={0}>Hz</option>
                  <option value={1}>Ex</option>
                  <option value={2}>Ey</option>
                  <option value={3}>Energy</option>
                </select>
              </div>
            </>
          )}

          <div className="field">
            <label>Source X (relative)</label>
            <input
              type="number"
              min={0}
              max={1}
              step={0.05}
              value={srcX}
              onChange={(e) => setSrcX(Number(e.target.value))}
            />
          </div>
          {simType !== '1D' && (
            <div className="field">
              <label>Source Y (relative)</label>
              <input
                type="number"
                min={0}
                max={1}
                step={0.05}
                value={srcY}
                onChange={(e) => setSrcY(Number(e.target.value))}
              />
            </div>
          )}

          <h2>Materials</h2>
          <MatrixEditor
            size={matrixSize}
            matrix={matrix}
            activeMaterial={activeMaterial}
            onChange={setMatrix}
            onActiveMaterial={setActiveMaterial}
          />

          <div className="btn-row">
            <button type="button" className="btn primary" onClick={onStart}>
              Start
            </button>
            <button type="button" className="btn" onClick={pause}>
              Pause
            </button>
            <button type="button" className="btn" onClick={() => cont(simType)}>
              Continue
            </button>
            <button type="button" className="btn" onClick={stop}>
              Stop
            </button>
          </div>
          <div className="status">
            WS: {status}
            {lastError ? ` — ${lastError}` : ''}
          </div>
        </aside>

        <main className="panel">
          <h2>Field</h2>
          <FieldViz mode={simType} frame={frame} />
        </main>
      </div>
    </div>
  )
}
