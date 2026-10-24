import {
  ClientMessageSchema,
  type ControlMessage,
  type SimType,
} from '@fdtd-online/protocol'
import { Fdtd1D, Fdtd2D, Fdtd2DTFSF } from '@fdtd-online/native'

type SendFn = (data: string) => void

type Solver =
  | { kind: '1D'; sim: InstanceType<typeof Fdtd1D> }
  | { kind: '2D'; sim: InstanceType<typeof Fdtd2D> }
  | { kind: '2D_TFSF'; sim: InstanceType<typeof Fdtd2DTFSF> }

/** One simulation session bound to a single WebSocket. */
export class SimSession {
  private interval: ReturnType<typeof setInterval> | null = null
  private solver: Solver | null = null
  private lastConfig: ControlMessage | null = null
  private readonly intervalMs = 80
  private readonly stepsPerTick = 2

  constructor(private readonly send: SendFn) {}

  handleRaw(raw: string | Buffer) {
    let parsed: unknown
    try {
      parsed = JSON.parse(raw.toString())
    } catch {
      return
    }
    const msg = ClientMessageSchema.safeParse(parsed)
    if (!msg.success) return

    if ('step' in msg.data && !('event' in msg.data)) {
      return // ack — reserved for future backpressure
    }

    const control = msg.data as ControlMessage
    switch (control.event) {
      case 'start':
        this.start(control)
        break
      case 'pause':
        this.pause()
        break
      case 'continue':
        this.continue()
        break
      case 'close':
        this.close()
        break
    }
  }

  private start(msg: ControlMessage) {
    this.pause()
    this.lastConfig = msg
    const type = (msg.type ?? '1D') as SimType
    this.solver = this.createSolver(type, msg)
    this.pump()
  }

  private continue() {
    if (!this.solver && this.lastConfig) {
      this.solver = this.createSolver(
        (this.lastConfig.type ?? '1D') as SimType,
        this.lastConfig,
      )
    }
    this.pump()
  }

  private pause() {
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
  }

  close() {
    this.pause()
    this.solver = null
  }

  private createSolver(type: SimType, msg: ControlMessage): Solver {
    const materials = msg.materials ?? [{ id: 0, eps: 1, mu: 1, sigma: 0 }]
    const matrix = msg.materialMatrix ?? [[0]]
    const flat = matrix.flat()
    const eps = materials.map((m) => m.eps)
    const mu = materials.map((m) => m.mu)
    const sigma = materials.map((m) => m.sigma)
    const src = msg.srcPositionRelative ?? [{ x: 0.3, y: 0.5 }]
    const srcPosition = src.flatMap((p) => [p.x, p.y])
    const condition = msg.condition ?? [1.0, 8.0]

    if (type === '1D') {
      return {
        kind: '1D',
        sim: new Fdtd1D({
          omega: condition[0],
          tau: condition[1],
          isReload: true,
          materialVector: flat,
          eps,
          mu,
          sigma,
          srcPosition,
        }),
      }
    }
    if (type === '2D_TFSF') {
      return {
        kind: '2D_TFSF',
        sim: new Fdtd2DTFSF({
          materialVector: flat,
          eps,
          mu,
          sigma,
        }),
      }
    }
    return {
      kind: '2D',
      sim: new Fdtd2D({
        lambda: condition[0],
        beamsize: condition[1],
        isReload: true,
        materialVector: flat,
        eps,
        mu,
        sigma,
        dataReturnType: msg.dataToReturn ?? 0,
        srcPosition,
        srcType: msg.srcType ?? 1,
      }),
    }
  }

  private pump() {
    this.pause()
    this.interval = setInterval(() => {
      if (!this.solver) return
      let payload: Record<string, unknown> | null = null
      for (let i = 0; i < this.stepsPerTick; i++) {
        if (this.solver.kind === '1D') {
          const d = this.solver.sim.getNextTimeLayer()
          payload = {
            kind: '1d',
            dataX: d.dataX,
            dataY: d.dataHy,
            dataEx: d.dataEx,
            dataHy: d.dataHy,
            step: d.currentTick,
            col: d.col,
            max: d.maxEx,
            min: d.minEx,
          }
        } else if (this.solver.kind === '2D') {
          const d = this.solver.sim.getNextTimeLayer()
          payload = {
            kind: '2d',
            dataX: d.dataX,
            dataY: d.dataY,
            dataVal: d.field,
            hz: d.hz,
            ex: d.ex,
            ey: d.ey,
            step: d.timeStep,
            row: d.rows,
            col: d.cols,
            max: d.max,
            min: d.min,
          }
        } else {
          const d = this.solver.sim.getNextTimeLayer()
          payload = {
            kind: '2d',
            dataX: d.dataX,
            dataY: d.dataY,
            dataVal: d.ez,
            hz: d.hz,
            ez: d.ez,
            step: d.timeStep,
            row: d.rows,
            col: d.cols,
            max: d.max,
            min: d.min,
          }
        }
      }
      if (payload) this.send(JSON.stringify(payload))
    }, this.intervalMs)
  }
}
