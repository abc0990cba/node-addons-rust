import { useEffect, useRef, useState } from 'react'
import type { ControlMessage, SimType } from '@fdtd-online/protocol'

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

export function useFdtdSocket(url = defaultUrl()) {
  const wsRef = useRef<WebSocket | null>(null)
  const [status, setStatus] = useState<'idle' | 'open' | 'closed' | 'error'>('idle')
  const [frame, setFrame] = useState<FramePayload | null>(null)
  const [lastError, setLastError] = useState<string | null>(null)

  useEffect(() => {
    const ws = new WebSocket(url)
    wsRef.current = ws
    ws.onopen = () => setStatus('open')
    ws.onclose = () => setStatus('closed')
    ws.onerror = () => {
      setStatus('error')
      setLastError('WebSocket error')
    }
    ws.onmessage = (ev) => {
      try {
        const data = JSON.parse(String(ev.data)) as FramePayload
        setFrame(data)
        if (typeof data.step === 'number') {
          ws.send(JSON.stringify({ step: data.step }))
        }
      } catch {
        /* ignore */
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
    send({ event: 'start', ...partial })
  }
  const pause = () => send({ event: 'pause' })
  const cont = (type: SimType) => send({ event: 'continue', type })
  const stop = () => send({ event: 'close' })

  return { status, frame, lastError, start, pause, continue: cont, stop }
}
