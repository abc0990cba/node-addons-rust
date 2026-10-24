/** 1D line plot — ported algorithm from legacy PlotLine / canvas-draw. */
export function drawPlotLine(
  canvas: HTMLCanvasElement,
  xs: number[],
  ys: number[],
  opts?: { min?: number; max?: number; color?: string },
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
    const x = pad + ((xs[i] - xmin) / xspan) * (w - 2 * pad)
    const y = h - pad - ((ys[i] - ymin) / yspan) * (h - 2 * pad)
    if (i === 0) ctx.moveTo(x, y)
    else ctx.lineTo(x, y)
  }
  ctx.stroke()
}
