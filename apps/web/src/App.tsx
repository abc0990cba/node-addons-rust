import { useMemo, useState } from 'react'
import { MatrixEditor } from './components/MatrixEditor'
import { FieldViz } from './components/FieldViz'
import { useFdtdSocket } from './hooks/useFdtdSocket'
import { upsampleEps1d } from './lib/detector'
import {
  EXPERIMENTS,
  experimentById,
  type ExperimentId,
} from './lib/experiments'
import { DEFAULT_MATERIALS, toWireMaterials, type UiMaterial } from './lib/materials'

export function App() {
  const { status, frame, lastError, start, pause, continue: cont, stop } =
    useFdtdSocket()

  const [experimentId, setExperimentId] = useState<ExperimentId>('1d-barrier')
  const experiment = experimentById(experimentId)

  const [materials, setMaterials] = useState<UiMaterial[]>(() =>
    DEFAULT_MATERIALS.map((m) => ({ ...m })),
  )
  const [matrix, setMatrix] = useState(() =>
    experiment.buildMatrix(experiment.gridSize, DEFAULT_MATERIALS),
  )
  const [activeMaterial, setActiveMaterial] = useState(1)
  const [srcX, setSrcX] = useState(experiment.src.x)
  const [srcY, setSrcY] = useState(experiment.src.y)
  const [omega, setOmega] = useState(experiment.omega ?? 1)
  const [tau, setTau] = useState(experiment.tau ?? 8)
  const [lambda, setLambda] = useState(experiment.lambda ?? 50)
  const [beamsize, setBeamsize] = useState(experiment.beamsize ?? 20)
  const [srcType, setSrcType] = useState(experiment.srcType ?? 1)
  const [dataToReturn, setDataToReturn] = useState(experiment.dataToReturn ?? 0)
  const [detectorCoord, setDetectorCoord] = useState(0.7)
  const [detectorDir, setDetectorDir] = useState<'vertical' | 'horizontal'>(
    'vertical',
  )

  const applyExperiment = (id: ExperimentId) => {
    const e = experimentById(id)
    setExperimentId(id)
    setMatrix(e.buildMatrix(e.gridSize, materials))
    setSrcX(e.src.x)
    setSrcY(e.src.y)
    if (e.omega != null) setOmega(e.omega)
    if (e.tau != null) setTau(e.tau)
    if (e.lambda != null) setLambda(e.lambda)
    if (e.beamsize != null) setBeamsize(e.beamsize)
    if (e.srcType != null) setSrcType(e.srcType)
    if (e.dataToReturn != null) setDataToReturn(e.dataToReturn)
  }

  const simType = experiment.simType
  const matrixRows = matrix.length
  const matrixCols = matrix[0]?.length ?? 0

  const condition = useMemo(
    (): [number, number] =>
      simType === '1D' ? [omega, tau] : [lambda, beamsize],
    [simType, omega, tau, lambda, beamsize],
  )

  const materialColors = useMemo(() => {
    const m: Record<number, string> = {}
    for (const mat of materials) m[mat.id] = mat.color
    return m
  }, [materials])

  const epsOverlay = useMemo(() => {
    if (simType !== '1D' || !frame?.col) return undefined
    const row = matrix[0] ?? []
    return upsampleEps1d(row, materials, frame.col)
  }, [simType, frame?.col, matrix, materials])

  const onStart = () => {
    // 1D: send a single row so the native upsampler maps barrier correctly.
    const materialMatrix =
      simType === '1D' ? [matrix[0] ?? Array(matrixCols).fill(0)] : matrix

    start({
      type: simType,
      condition,
      materialMatrix,
      materials: toWireMaterials(materials),
      srcPositionRelative: [{ x: srcX, y: srcY }],
      srcType,
      dataToReturn,
    })
  }

  const updateMaterial = (
    id: number,
    patch: Partial<Pick<UiMaterial, 'eps' | 'mu' | 'sigma'>>,
  ) => {
    setMaterials((prev) =>
      prev.map((m) => (m.id === id ? { ...m, ...patch } : m)),
    )
  }

  return (
    <div className="app-shell">
      <h1 className="brand">Nanophotonics with FDTD</h1>
      <p className="tagline">
        Lab experiments: 1D pulse / barrier, 2D waveguide & diffraction, TF/SF
        plane wave — Rust physics over WebSocket.
      </p>

      <div className="layout">
        <aside className="panel">
          <h2>Experiment</h2>
          <div className="field">
            <label>Demo preset</label>
            <select
              value={experimentId}
              onChange={(e) => applyExperiment(e.target.value as ExperimentId)}
            >
              {EXPERIMENTS.map((e) => (
                <option key={e.id} value={e.id}>
                  {e.label}
                </option>
              ))}
            </select>
          </div>
          <p className="status" style={{ marginBottom: '0.75rem' }}>
            {experiment.blurb}
          </p>

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
              {simType === '2D' && (
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
                <label>Detector position</label>
                <input
                  type="number"
                  min={0}
                  max={1}
                  step={0.05}
                  value={detectorCoord}
                  onChange={(e) => setDetectorCoord(Number(e.target.value))}
                />
              </div>
              <div className="field">
                <label>Detector direction</label>
                <select
                  value={detectorDir}
                  onChange={(e) =>
                    setDetectorDir(e.target.value as 'vertical' | 'horizontal')
                  }
                >
                  <option value="vertical">Vertical</option>
                  <option value="horizontal">Horizontal</option>
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
          {materials.map((m) => (
            <div key={m.id} className="material-edit">
              <div className="status">
                <span
                  className="swatch"
                  style={{ background: m.color }}
                />{' '}
                {m.name}
              </div>
              <div className="field-row">
                <label>
                  ε
                  <input
                    type="number"
                    step="0.1"
                    value={m.eps}
                    onChange={(e) =>
                      updateMaterial(m.id, { eps: Number(e.target.value) })
                    }
                  />
                </label>
                <label>
                  μ
                  <input
                    type="number"
                    step="0.1"
                    value={m.mu}
                    onChange={(e) =>
                      updateMaterial(m.id, { mu: Number(e.target.value) })
                    }
                  />
                </label>
                <label>
                  σ
                  <input
                    type="number"
                    step="0.01"
                    value={m.sigma}
                    onChange={(e) =>
                      updateMaterial(m.id, { sigma: Number(e.target.value) })
                    }
                  />
                </label>
              </div>
            </div>
          ))}

          <h2>Geometry</h2>
          <MatrixEditor
            rows={matrixRows}
            cols={matrixCols}
            matrix={matrix}
            activeMaterial={activeMaterial}
            materialColors={materialColors}
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
          <FieldViz
            mode={simType}
            frame={frame}
            epsOverlay={epsOverlay}
            srcRelX={srcX}
            detector={
              simType === '1D'
                ? undefined
                : { relativeCoord: detectorCoord, direction: detectorDir }
            }
          />
        </main>
      </div>
    </div>
  )
}
