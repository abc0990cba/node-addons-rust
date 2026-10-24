/** 1D line plot — ported from legacy PlotLine / canvas-draw (+ ε overlay). */

export type EpsOverlay = {
  /** Relative permittivity samples along x (length = grid cells or data length). */
  eps: number[]
}

export function drawPlotLine(
  canvas: HTMLCanvasElement,
  xs: number[],
  ys: number[],
  opts?: {
    min?: number
    max?: number
    color?: string
    epsOverlay?: EpsOverlay
    srcMarkerRel?: number
  },
) {
  const ctx = canvas.getContext('2d')
  if (!ctx || xs.length === 0) return
  const w = canvas.width
  const h = canvas.height
  const pad = 28
  ctx.clearRect(0, 0, w, h)
  ctx.fillStyle = '#0a0e13'
  ctx.fillRect(0, 0, w, h)

  let ymin = opts?.min ?? Infinity
  let ymax = opts?.max ?? -Infinity
  if (!Number.isFinite(ymin) || !Number.isFinite(ymax)) {
    ymin = Infinity
    ymax = -Infinity
    for (const y of ys) {
      ymin = Math.min(ymin, y)
      ymax = Math.max(ymax, y)
    }
  }
  if (ymin === ymax) {
    ymin -= 1
    ymax += 1
  }

  const xmin = xs[0]
  const xmax = xs[xs.length - 1] || 1
  const xspan = xmax - xmin || 1
  const yspan = ymax - ymin || 1
  const chartW = w - 2 * pad
  const chartH = h - 2 * pad

  // ε bars (legacy overlay) — bottom strip
  if (opts?.epsOverlay?.eps?.length) {
    const eps = opts.epsOverlay.eps
    const maxEps = Math.max(1, ...eps)
    for (let i = 0; i < eps.length; i++) {
      const x0 = pad + (i / eps.length) * chartW
      const x1 = pad + ((i + 1) / eps.length) * chartW
      const barH = ((eps[i] - 1) / (maxEps - 1 || 1)) * (chartH * 0.28)
      ctx.fillStyle = 'rgba(232, 160, 74, 0.35)'
      ctx.fillRect(x0, h - pad - barH, Math.max(1, x1 - x0), barH)
    }
  }

  ctx.strokeStyle = 'rgba(232,238,244,0.15)'
  ctx.beginPath()
  ctx.moveTo(pad, pad)
  ctx.lineTo(pad, h - pad)
  ctx.lineTo(w - pad, h - pad)
  ctx.stroke()

  ctx.strokeStyle = opts?.color ?? '#3db8a0'
  ctx.lineWidth = 1.5
  ctx.beginPath()
  for (let i = 0; i < ys.length; i++) {
    const x = pad + ((xs[i] - xmin) / xspan) * chartW
    const y = h - pad - ((ys[i] - ymin) / yspan) * chartH
    if (i === 0) ctx.moveTo(x, y)
    else ctx.lineTo(x, y)
  }
  ctx.stroke()

  if (opts?.srcMarkerRel != null) {
    const x = pad + opts.srcMarkerRel * chartW
    ctx.strokeStyle = 'rgba(61, 184, 160, 0.7)'
    ctx.setLineDash([4, 4])
    ctx.beginPath()
    ctx.moveTo(x, pad)
    ctx.lineTo(x, h - pad)
    ctx.stroke()
    ctx.setLineDash([])
  }
}
