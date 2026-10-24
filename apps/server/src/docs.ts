export const docsHtml = `<!doctype html>
<html><head><meta charset="utf-8"/><title>FDTD Online API</title>
<style>body{font-family:ui-monospace,monospace;max-width:52rem;margin:2rem auto;padding:0 1rem;line-height:1.45}
code{background:#f4f4f4;padding:.1rem .3rem}</style></head><body>
<h1>FDTD Online — WebSocket API</h1>
<p>Connect to <code>ws://HOST:PORT/</code>. One simulation session per socket.</p>
<h2>Client → server</h2>
<pre>{
  "event": "start" | "pause" | "continue" | "close",
  "type": "1D" | "2D" | "2D_TFSF",
  "dataToReturn": 0,          // 0=Hz, 1=Ex, 2=Ey, 3=Energy
  "condition": [a, b],        // 1D: [omega, tau]; 2D: [lambda, beamsize]
  "materialMatrix": [[0,1],…],
  "materials": [{ "id":0, "eps":1, "mu":1, "sigma":0 }],
  "srcPositionRelative": [{ "x":0.3, "y":0.5 }],
  "srcType": 1                // 1=soft sin, else hard gaussian-sin
}</pre>
<p>Ack frames: <code>{ "step": N }</code></p>
<h2>Server → client</h2>
<p>JSON field frames (<code>dataX</code>/<code>dataY</code>/<code>dataVal</code>/minmax). Field names use <code>hz</code>/<code>ex</code>/<code>ey</code> (legacy <code>dataEz</code> misnomer fixed).</p>
<p>HTTP: <code>GET /health</code>, <code>GET /docs</code></p>
</body></html>`
