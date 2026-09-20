const http = require("http");
const path = require("path");
const { WebSocketServer } = require("ws");
const { replayCsv } = require("./simulationBridge");

const PORT = Number(process.env.BRIDGE_PORT || 8787);
const CSV = process.env.SIM_CSV ||
  path.resolve(__dirname, "../simulation/output/simulation_results.csv");

const clients = new Set();

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, {"Content-Type":"application/json"});
    res.end(JSON.stringify({ok:true, service:"mppt-simulation-bridge"}));
    return;
  }
  res.writeHead(404);
  res.end("Not found");
});

const wss = new WebSocketServer({ server, path: "/ws/simulation" });

wss.on("connection", ws => {
  clients.add(ws);
  ws.send(JSON.stringify({type:"status", mode:"SIMULATION", connected:true}));

  ws.on("message", msg => {
    // Command channel is intentionally explicit. Live MATLAB command execution
    // should be added only after the Simulink control interface is wired.
    try {
      const command = JSON.parse(msg.toString());
      console.log("simulation command:", command);
    } catch {}
  });

  ws.on("close", () => clients.delete(ws));
});

function broadcast(message) {
  for (const ws of clients) {
    if (ws.readyState === 1) ws.send(message);
  }
}

server.listen(PORT, () => {
  console.log(`MPPT simulation bridge: http://localhost:${PORT}`);
  console.log(`WebSocket: ws://localhost:${PORT}/ws/simulation`);
  console.log(`CSV: ${CSV}`);
});

if (require.main === module) {
  const start = () => {
    if (!require("fs").existsSync(CSV)) {
      console.log("No simulation_results.csv yet.");
      console.log("Run Simulink export first, then restart the bridge.");
      return;
    }
    replayCsv(CSV, broadcast, {hz:20}).catch(console.error);
  };
  setTimeout(start, 500);
}
