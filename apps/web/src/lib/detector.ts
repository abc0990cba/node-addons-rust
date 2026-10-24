/** Slice a 2D row-major field along a line detector (legacy client). */
export function sliceDetector(
  field: number[],
  rows: number,
  cols: number,
  relativeCoord: number,
  direction: 'vertical' | 'horizontal',
): { xs: number[]; ys: number[] } {
  const xs: number[] = []
  const ys: number[] = []
  if (rows <= 0 || cols <= 0 || field.length === 0) return { xs, ys }
  const t = Math.min(1, Math.max(0, relativeCoord))
  if (direction === 'vertical') {
    const col = Math.min(cols - 1, Math.floor(t * cols))
    for (let r = 0; r < rows; r++) {
      xs.push(r)
      ys.push(field[r * cols + col] ?? 0)
    }
  } else {
    const row = Math.min(rows - 1, Math.floor(t * rows))
    for (let c = 0; c < cols; c++) {
      xs.push(c)
      ys.push(field[row * cols + c] ?? 0)
    }
  }
  return { xs, ys }
}

/** Upsample a coarse material id row to the solver grid length for ε overlay. */
export function upsampleEps1d(
  matrixRow: number[],
  materials: { id: number; eps: number }[],
  targetLen: number,
): number[] {
  const src = matrixRow.length > 0 ? matrixRow : [0]
  const byId = new Map(materials.map((m) => [m.id, m.eps]))
  const out = new Array<number>(targetLen)
  for (let i = 0; i < targetLen; i++) {
    const si = Math.floor((i * src.length) / targetLen)
    const id = src[Math.min(si, src.length - 1)] ?? 0
    out[i] = byId.get(id) ?? 1
  }
  return out
}
