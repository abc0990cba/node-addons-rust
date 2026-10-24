import { useEffect, useRef } from 'react'
import type { FramePayload } from '../hooks/useFdtdSocket'
import { sliceDetector } from '../lib/detector'
import { drawColorBar, HeatMapBuilder } from '../viz/heatmap'
import { drawPlotLine } from '../viz/plot-line'

type Detector = {
  relativeCoord: number
  direction: 'vertical' | 'horizontal'
}

type Props = {
  mode: '1D' | '2D' | '2D_TFSF'
  frame: FramePayload | null
  epsOverlay?: number[]
  srcRelX?: number
  detector?: Detector
}

export function FieldViz({
  mode,
  frame,
  epsOverlay,
  srcRelX,
  detector,
}: Props) {
  const mainRef = useRef<HTMLCanvasElement>(null)
  const detRef = useRef<HTMLCanvasElement>(null)
  const barRef = useRef<HTMLCanvasElement>(null)
  const gradRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    if (!frame || !mainRef.current) return
    if (mode === '1D') {
      const xs = frame.dataX ?? []
      const ys = frame.dataY ?? frame.dataEx ?? frame.dataHy ?? []
      drawPlotLine(mainRef.current, xs, ys, {
        min: frame.min,
        max: frame.max,
        epsOverlay: epsOverlay ? { eps: epsOverlay } : undefined,
        srcMarkerRel: srcRelX,
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

    // Detector overlay line on heatmap
    if (detector) {
      const ctx = mainRef.current.getContext('2d')
      if (ctx) {
        const t = detector.relativeCoord
        ctx.strokeStyle = 'rgba(232, 238, 244, 0.85)'
        ctx.lineWidth = 1.5
        ctx.setLineDash([6, 4])
        ctx.beginPath()
        if (detector.direction === 'vertical') {
          const x = t * mainRef.current.width
          ctx.moveTo(x, 0)
          ctx.lineTo(x, mainRef.current.height)
        } else {
          const y = t * mainRef.current.height
          ctx.moveTo(0, y)
          ctx.lineTo(mainRef.current.width, y)
        }
        ctx.stroke()
        ctx.setLineDash([])
      }
    }

    if (barRef.current) {
      drawColorBar(barRef.current, frame.min ?? -1, frame.max ?? 1)
    }

    if (detector && detRef.current) {
      const { xs, ys } = sliceDetector(
        vals,
        rows,
        cols,
        detector.relativeCoord,
        detector.direction,
      )
      drawPlotLine(detRef.current, xs, ys, { color: '#e8a04a' })
    }
  }, [frame, mode, epsOverlay, srcRelX, detector])

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
      {mode !== '1D' && detector && (
        <div>
          <div className="status">Line detector ({detector.direction})</div>
          <canvas
            ref={detRef}
            className="field-canvas"
            width={900}
            height={180}
          />
        </div>
      )}
      <canvas ref={gradRef} width={1} height={256} style={{ display: 'none' }} />
      <div className="status">
        step {frame?.step ?? '—'}
        {frame?.max != null && ` · max ${frame.max.toExponential(2)}`}
      </div>
    </div>
  )
}
