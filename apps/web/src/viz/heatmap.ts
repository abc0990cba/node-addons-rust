import { defaultGradient } from '../lib/default-gradient'

/** HeatMapBuilder — algorithm ported from legacy heatmap-builder (ImageData path). */
export class HeatMapBuilder {
  private grad: Uint8ClampedArray | null = null
  private ctx: CanvasRenderingContext2D | null
  private width: number
  private height: number
  private _max = 1
  private _min = -1
  private _realGridSize = 220
  dataX: number[] = []
  dataY: number[] = []
  dataVal: number[] = []

  constructor(
    private readonly canvas: HTMLCanvasElement,
    private readonly gradientCanvas: HTMLCanvasElement,
  ) {
    this.ctx = canvas.getContext('2d')
    this.width = canvas.width
    this.height = canvas.height
  }

  newData(dataX: number[], dataY: number[], dataVal: number[]) {
    this.dataX = dataX
    this.dataY = dataY
    this.dataVal = dataVal
    return this
  }

  realGridSize(n: number) {
    this._realGridSize = n
    return this
  }

  max(v: number) {
    this._max = v
    return this
  }

  min(v: number) {
    this._min = v
    return this
  }

  gradient(grad: Record<string, string> = defaultGradient) {
    const ctx = this.gradientCanvas.getContext('2d')
    if (!ctx) return this
    this.gradientCanvas.width = 1
    this.gradientCanvas.height = 256
    const g = ctx.createLinearGradient(0, 0, 0, 256)
    for (const [k, c] of Object.entries(grad)) g.addColorStop(Number(k), c)
    ctx.fillStyle = g
    ctx.fillRect(0, 0, 1, 256)
    this.grad = ctx.getImageData(0, 0, 1, 256).data
    return this
  }

  private colorize(pixels: Uint8ClampedArray, grad: Uint8ClampedArray) {
    for (let i = 0; i < pixels.length; i += 4) {
      const a = pixels[i + 3]
      if (!a) continue
      const idx = a * 4
      pixels[i] = grad[idx]
      pixels[i + 1] = grad[idx + 1]
      pixels[i + 2] = grad[idx + 2]
      pixels[i + 3] = 255
    }
  }

  /** Draw dense grid values (row-major) onto canvas. */
  drawGrid(rows: number, cols: number) {
    if (!this.grad) this.gradient()
    if (!this.ctx || !this.grad) return this
    this.width = this.canvas.width
    this.height = this.canvas.height
    const img = this.ctx.createImageData(this.width, this.height)
    const pixels = img.data
    const span = Math.abs(this._max - this._min) || 1
    const minOpacity = 0.08

    for (let j = 0; j < rows; j++) {
      for (let i = 0; i < cols; i++) {
        const v = this.dataVal[j * cols + i] ?? 0
        const alpha = Math.min(Math.max((v + Math.abs(this._min)) / span, minOpacity), 1)
        const x0 = Math.floor((i * this.width) / cols)
        const x1 = Math.floor(((i + 1) * this.width) / cols)
        const y0 = Math.floor((j * this.height) / rows)
        const y1 = Math.floor(((j + 1) * this.height) / rows)
        const a = Math.floor(255 * alpha)
        for (let y = y0; y < y1; y++) {
          for (let x = x0; x < x1; x++) {
            const k = (y * this.width + x) * 4
            pixels[k] = 0
            pixels[k + 1] = 0
            pixels[k + 2] = 0
            pixels[k + 3] = a
          }
        }
      }
    }
    this.colorize(pixels, this.grad)
    this.ctx.putImageData(img, 0, 0)
    return this
  }
}

export function drawColorBar(
  canvas: HTMLCanvasElement,
  min: number,
  max: number,
  grad: Record<string, string> = defaultGradient,
) {
  const ctx = canvas.getContext('2d')
  if (!ctx) return
  const g = ctx.createLinearGradient(0, canvas.height, 0, 0)
  for (const [k, c] of Object.entries(grad)) g.addColorStop(Number(k), c)
  ctx.fillStyle = g
  ctx.fillRect(0, 0, canvas.width, canvas.height)
  ctx.fillStyle = '#e8eef4'
  ctx.font = '11px IBM Plex Sans, sans-serif'
  ctx.fillText(max.toExponential(2), 4, 12)
  ctx.fillText(min.toExponential(2), 4, canvas.height - 4)
}
