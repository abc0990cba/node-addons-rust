type Props = {
  size: number
  matrix: number[][]
  activeMaterial: number
  onChange: (m: number[][]) => void
  onActiveMaterial: (id: number) => void
}

export function MatrixEditor({
  size,
  matrix,
  activeMaterial,
  onChange,
  onActiveMaterial,
}: Props) {
  const paint = (r: number, c: number) => {
    const next = matrix.map((row) => row.slice())
    next[r][c] = activeMaterial
    onChange(next)
  }

  const fill = (id: number) => {
    onChange(Array.from({ length: size }, () => Array.from({ length: size }, () => id)))
  }

  return (
    <div>
      <div className="field">
        <label>Paint material</label>
        <select
          value={activeMaterial}
          onChange={(e) => onActiveMaterial(Number(e.target.value))}
        >
          <option value={0}>0 — vacuum</option>
          <option value={1}>1 — dielectric</option>
          <option value={2}>2 — metal-like</option>
        </select>
      </div>
      <div className="btn-row">
        <button type="button" className="btn" onClick={() => fill(0)}>
          Clear
        </button>
        <button
          type="button"
          className="btn"
          onClick={() => {
            const next = matrix.map((row) => row.slice())
            const mid = Math.floor(size / 2)
            for (let r = 0; r < size; r++) next[r][mid] = 1
            onChange(next)
          }}
        >
          Slab
        </button>
      </div>
      <div
        className="matrix-grid"
        style={{ gridTemplateColumns: `repeat(${size}, 1fr)` }}
      >
        {matrix.map((row, r) =>
          row.map((id, c) => (
            <button
              key={`${r}-${c}`}
              type="button"
              className="matrix-cell"
              data-id={id}
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

export function defaultMatrix(size: number): number[][] {
  return Array.from({ length: size }, () => Array.from({ length: size }, () => 0))
}
