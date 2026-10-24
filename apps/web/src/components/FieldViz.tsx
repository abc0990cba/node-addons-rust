import { useEffect, useRef } from 'react'
import type { FramePayload } from '../hooks/useFdtdSocket'
import { drawColorBar, HeatMapBuilder } from '../viz/heatmap'
import { drawPlotLine } from '../viz/plot-line'

type Props = {
  mode: '1D' | '2D' | '2D_TFSF'
  frame: FramePayload | null
}

export function FieldViz({ mode, frame }: Props) {
  const mainRef = useRef<HTMLCanvasElement>(null)
  const barRef = useRef<HTMLCanvasElement>(null)
  const gradRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    if (!frame || !mainRef.current) return
    if (mode === '1D') {
      const xs = frame.dataX ?? []
      const ys = frame.dataY ?? frame.dataHy ?? frame.dataEx ?? []
      drawPlotLine(mainRef.current, xs, ys, {
        min: frame.min,
        max: frame.max,
      })
      return
    }

    const rows = frame.row ?? Math.round(Math.sqrt(frame.dataVal?.length ?? 0))
    const cols = frame.col ?? rows
    const vals = frame.dataVal ?? frame.hz ?? frame.ez ?? []
    if (!gradRef.current) return
    const builder = new HeatMapBuilder(mainRef.current, gradRef.current)
    builder
      .realGridSize(cols)
      .min(frame.min ?? -1)
      .max(frame.max ?? 1)
      .newData(
        Array.from({ length: cols }, (_, i) => i),
        Array.from({ length: rows }, (_, j) => j),
        vals,
      )
      .drawGrid(rows, cols)
    if (barRef.current) {
      drawColorBar(barRef.current, frame.min ?? -1, frame.max ?? 1)
    }
  }, [frame, mode])

  return (
    <div className="viz-wrap">
      <div className="viz-row">
        <canvas
          ref={mainRef}
          className="field-canvas"
          width={mode === '1D' ? 900 : 520}
          height={mode === '1D' ? 280 : 520}
        />
        {mode !== '1D' && (
          <canvas ref={barRef} width={56} height={520} className="field-canvas" />
        )}
      </div>
      <canvas ref={gradRef} width={1} height={256} style={{ display: 'none' }} />
      <div className="status">
        step {frame?.step ?? '—'}
        {frame?.max != null && ` · max ${frame.max.toExponential(2)}`}
      </div>
    </div>
  )
}
