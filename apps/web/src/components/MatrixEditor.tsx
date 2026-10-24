type Props = {
  /** For 1D experiments matrix is 1×N; for 2D it is N×N. */
  rows: number
  cols: number
  matrix: number[][]
  activeMaterial: number
  materialColors: Record<number, string>
  onChange: (m: number[][]) => void
  onActiveMaterial: (id: number) => void
}

export function MatrixEditor({
  rows,
  cols,
  matrix,
  activeMaterial,
  materialColors,
  onChange,
  onActiveMaterial,
}: Props) {
  const paint = (r: number, c: number) => {
    const next = matrix.map((row) => row.slice())
    if (!next[r]) return
    next[r][c] = activeMaterial
    onChange(next)
  }

  const fill = (id: number) => {
    onChange(
      Array.from({ length: rows }, () =>
        Array.from({ length: cols }, () => id),
      ),
    )
  }

  return (
    <div>
      <div className="field">
        <label>Paint material</label>
        <select
          value={activeMaterial}
          onChange={(e) => onActiveMaterial(Number(e.target.value))}
        >
          <option value={0}>0 — free space</option>
          <option value={1}>1 — dielectric</option>
          <option value={2}>2 — lossy / metal-like</option>
        </select>
      </div>
      <div className="btn-row">
        <button type="button" className="btn" onClick={() => fill(0)}>
          Clear
        </button>
      </div>
      <div
        className="matrix-grid"
        style={{
          gridTemplateColumns: `repeat(${cols}, 1fr)`,
          maxHeight: rows === 1 ? 48 : undefined,
        }}
      >
        {matrix.map((row, r) =>
          row.map((id, c) => (
            <button
              key={`${r}-${c}`}
              type="button"
              className="matrix-cell"
              data-id={id}
              style={{
                background: materialColors[id] ?? undefined,
                minHeight: rows === 1 ? 28 : undefined,
              }}
              aria-label={`cell ${r},${c}`}
              onMouseDown={() => paint(r, c)}
              onMouseEnter={(e) => {
                if (e.buttons === 1) paint(r, c)
              }}
            />
          )),
        )}
      </div>
    </div>
  )
}

export function defaultMatrix(rows: number, cols: number): number[][] {
  return Array.from({ length: rows }, () =>
    Array.from({ length: cols }, () => 0),
  )
}
