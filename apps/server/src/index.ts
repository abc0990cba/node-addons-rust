import http from 'node:http'
import express from 'express'
import { WebSocketServer } from 'ws'
import { docsHtml } from './docs.js'
import { SimSession } from './session.js'

const PORT = Number(process.env.PORT ?? 5001)

const app = express()
app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'fdtd-online-server' })
})
app.get('/docs', (_req, res) => {
  res.type('html').send(docsHtml)
})

const server = http.createServer(app)
const wss = new WebSocketServer({ server })

wss.on('connection', (socket) => {
  const session = new SimSession((data) => {
    if (socket.readyState === socket.OPEN) socket.send(data)
  })
  socket.on('message', (data) => session.handleRaw(data as Buffer))
  socket.on('close', () => session.close())
  socket.on('error', () => session.close())
})

server.listen(PORT, () => {
  console.log(`FDTD Online server on http://localhost:${PORT} (WS + /health + /docs)`)
})
