import { useEffect, useRef, useState } from 'react'
import {
  decodeBinaryFrame,
  isBinaryFrame,
  type ControlMessage,
  type SimType,
} from '@fdtd-online/protocol'

export type FramePayload = {
  kind?: string
  dataX?: number[]
  dataY?: number[]
  dataVal?: number[]
  dataEx?: number[]
  dataHy?: number[]
  hz?: number[]
  ex?: number[]
  ey?: number[]
  ez?: number[]
  step?: number
  row?: number
  col?: number
  max?: number
  min?: number
}

const defaultUrl = () =>
  import.meta.env.VITE_WS_URL ??
  `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.hostname}:5001`

function frameFromBinary(buf: ArrayBuffer): FramePayload {
  const d = decodeBinaryFrame(buf)
  if (d.kind === '1d') {
    return {
      kind: '1d',
      dataX: d.dataX,
      dataY: d.dataY,
      dataHy: d.dataY,
      step: d.step,
      col: d.col,
      row: 1,
      min: d.min,
      max: d.max,
    }
  }
  return {
    kind: '2d',
    dataX: d.dataX,
    dataY: d.dataY,
    dataVal: d.dataVal,
    step: d.step,
    row: d.row,
    col: d.col,
    min: d.min,
    max: d.max,
  }
}

export function useFdtdSocket(url = defaultUrl()) {
  const wsRef = useRef<WebSocket | null>(null)
  const [status, setStatus] = useState<'idle' | 'open' | 'closed' | 'error'>('idle')
  const [frame, setFrame] = useState<FramePayload | null>(null)
  const [lastError, setLastError] = useState<string | null>(null)

  useEffect(() => {
    const ws = new WebSocket(url)
    ws.binaryType = 'arraybuffer'
    wsRef.current = ws
    ws.onopen = () => setStatus('open')
    ws.onclose = () => setStatus('closed')
    ws.onerror = () => {
      setStatus('error')
      setLastError('WebSocket error')
    }
    ws.onmessage = (ev) => {
      try {
        let data: FramePayload
        if (ev.data instanceof ArrayBuffer) {
          if (!isBinaryFrame(ev.data)) return
          data = frameFromBinary(ev.data)
        } else if (typeof Blob !== 'undefined' && ev.data instanceof Blob) {
          // Rare path — read then decode asynchronously
          ev.data.arrayBuffer().then((ab) => {
            if (!isBinaryFrame(ab)) return
            const f = frameFromBinary(ab)
            setFrame(f)
            if (typeof f.step === 'number' && ws.readyState === WebSocket.OPEN) {
              ws.send(JSON.stringify({ step: f.step }))
            }
          })
          return
        } else {
          data = JSON.parse(String(ev.data)) as FramePayload
        }
        setFrame(data)
        if (typeof data.step === 'number') {
          ws.send(JSON.stringify({ step: data.step }))
        }
      } catch (err) {
        setLastError(err instanceof Error ? err.message : 'frame decode error')
      }
    }
    return () => {
      ws.close()
      wsRef.current = null
    }
  }, [url])

  const send = (msg: ControlMessage) => {
    const ws = wsRef.current
    if (!ws || ws.readyState !== WebSocket.OPEN) {
      setLastError('Socket not open')
      return
    }
    ws.send(JSON.stringify(msg))
  }

  const start = (partial: Omit<ControlMessage, 'event'> & { type: SimType }) => {
    send({ event: 'start', frameFormat: 'binary', ...partial })
  }
  const pause = () => send({ event: 'pause' })
  const cont = (type: SimType) => send({ event: 'continue', type })
  const stop = () => send({ event: 'close' })

  return { status, frame, lastError, start, pause, continue: cont, stop }
}
