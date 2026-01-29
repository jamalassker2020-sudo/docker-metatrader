<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>HFT Ultra FX 2026</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
:root{--bg:#0a0e14;--card:#121820;--border:#1a2030;--txt:#c8d0dc;--dim:#5a6270;--g:#0f6;--r:#f44;--b:#0af;--y:#fc0}
html.light{--bg:#f4f6f8;--card:#fff;--border:#dde;--txt:#1a1a2e;--dim:#888}
body{background:var(--bg);color:var(--txt);font:11px/1.4 monospace;padding:8px;min-height:100vh}
.g{color:var(--g)}.r{color:var(--r)}.b{color:var(--b)}.y{color:var(--y)}.dim{color:var(--dim)}
.card{background:var(--card);border:1px solid var(--border);border-radius:4px;padding:8px;margin-bottom:8px}
.row{display:flex;gap:8px;flex-wrap:wrap}
.col{flex:1;min-width:120px}
.grid{display:grid;gap:4px}
.g2{grid-template-columns:repeat(2,1fr)}.g3{grid-template-columns:repeat(3,1fr)}.g4{grid-template-columns:repeat(4,1fr)}.g6{grid-template-columns:repeat(6,1fr)}
.stat{background:var(--bg);padding:6px;border-radius:3px;text-align:center}
.stat small{display:block;font-size:9px;color:var(--dim);margin-bottom:2px}
.stat b{font-size:13px}
h1{font-size:14px;margin-bottom:4px}
table{width:100%;border-collapse:collapse;font-size:10px}
th,td{padding:4px;text-align:right}
th{color:var(--dim);font-weight:400;border-bottom:1px solid var(--border)}
td:first-child,th:first-child{text-align:left}
tr:hover{background:rgba(255,255,255,.02)}
.scroll{max-height:200px;overflow-y:auto}
.bar{height:40px;display:flex;align-items:end;gap:1px}
.bar div{flex:1;min-width:2px;border-radius:1px 1px 0 0}
.log{font-size:9px;padding:2px 4px;margin:1px 0;border-radius:2px;background:var(--bg)}
button{background:var(--card);border:1px solid var(--border);color:var(--txt);padding:4px 8px;border-radius:3px;cursor:pointer;font:inherit}
button:hover{background:var(--border)}
.pulse{animation:p 1.5s infinite}@keyframes p{50%{opacity:.5}}
.badge{display:inline-block;padding:2px 6px;border-radius:3px;font-size:9px}
.badge.on{background:#0f62;color:var(--g)}.badge.off{background:#f442;color:var(--r)}.badge.warn{background:#fc02;color:var(--y)}
input[type="text"]{background:var(--bg);border:1px solid var(--border);color:var(--txt);padding:4px 8px;border-radius:3px;font:inherit;width:100%;font-size:16px}
input[type="text"]:focus{outline:none;border-color:var(--b)}
.webhook-status{font-size:9px;margin-top:4px}
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.7);display:flex;align-items:center;justify-content:center;z-index:100}
.modal{background:var(--card);border:1px solid var(--border);border-radius:8px;padding:16px;max-width:400px;width:90%}
.modal h3{margin-bottom:12px;font-size:14px}
.modal-buttons{display:flex;gap:8px;justify-content:flex-end;margin-top:16px}
@media(max-width:600px){.g6{grid-template-columns:repeat(3,1fr)}.g4{grid-template-columns:repeat(2,1fr)}}
</style>
</head>
<body>
<div class="row" style="justify-content:space-between;align-items:center;margin-bottom:8px">
<div>
<h1>⚡ HFT ULTRA <span class="y">FX</span> <span class="dim">2026</span></h1>
<small class="dim">28 FOREX PAIRS • ECB + SIMULATED TICKS • SMART RISK • MT5 WEBHOOK</small>
</div>
<div class="row" style="gap:4px">
<span id="status" class="badge pulse">INIT</span>
<span id="api" class="badge dim">API:--</span>
<span id="webhook" class="badge dim">WH:--</span>
<span id="shield" class="badge">SHIELD:--</span>
<button onclick="showWebhookConfig()">⚙️</button>
<button onclick="reset()">⟲</button>
</div>
</div>

<div class="grid g6" style="margin-bottom:8px">
<div class="stat"><small>💰 EQUITY</small><b id="equity" class="g">$100.00</b><div id="pnlPct" style="font-size:9px">+0.00%</div></div>
<div class="stat"><small>P&L</small><b id="pnl">$0.00</b></div>
<div class="stat"><small>TRADES</small><b id="trades" class="b">0</b></div>
<div class="stat"><small>WIN%</small><b id="winrate" class="y">0%</b></div>
<div class="stat"><small>PROFIT F.</small><b id="pf" class="g">0.00</b></div>
<div class="stat"><small>OPEN</small><b id="openPos" class="b">0/6</b></div>
<div class="stat"><small>STREAK</small><b id="streak">0</b></div>
<div class="stat"><small>BEST</small><b id="best" class="g">$100</b></div>
<div class="stat"><small>DD</small><b id="dd" class="r">0%</b></div>
<div class="stat"><small>AVG WIN</small><b id="avgWin" class="g">$0</b></div>
<div class="stat"><small>AVG LOSS</small><b id="avgLoss" class="r">$0</b></div>
<div class="stat"><small>SHARPE</small><b id="sharpe" class="b">0.00</b></div>
</div>

<div class="row">
<div class="col" style="flex:3">
<div class="card">
<div class="row" style="justify-content:space-between;margin-bottom:4px">
<b class="b">📊 FOREX MARKET</b>
<span id="time" class="dim">--:--:--</span>
</div>
<div class="scroll"><table><thead><tr><th>PAIR</th><th>BID</th><th>ASK</th><th>SPR</th><th>RSI</th><th>MOM</th><th>SIG</th><th>P&L</th></tr></thead><tbody id="market"></tbody></table></div>
</div>
</div>
<div class="col">
<div class="card">
<b>📈 POSITIONS</b>
<div id="positions" class="scroll" style="margin-top:4px"><span class="dim">Scanning...</span></div>
</div>
<div class="card">
<b>⚡ LOG</b>
<div id="log" class="scroll" style="margin-top:4px"><span class="dim">Starting...</span></div>
</div>
</div>
</div>

<div class="row">
<div class="col">
<div class="card"><b>💹 EQUITY</b><div class="bar" id="chart"></div></div>
</div>
<div class="col">
<div class="card">
<b>🛡️ RISK SHIELD</b>
<div class="grid g3" style="margin-top:6px;font-size:9px;text-align:center">
<div class="stat"><small>MAX DD</small><span id="maxDD">5%</span></div>
<div class="stat"><small>DAILY LOSS</small><span id="dailyLoss">$0</span></div>
<div class="stat"><small>HEAT</small><span id="heat">0%</span></div>
<div class="stat"><small>LOT</small><span id="lotSize" class="b">0.01</span></div>
<div class="stat"><small>RR</small><span class="g">3:1</span></div>
<div class="stat"><small>CORR HEDGE</small><span id="hedge" class="y">ON</span></div>
</div>
</div>
</div>
</div>

<!-- Webhook Config Modal -->
<div id="webhookModal" class="modal-overlay" style="display:none">
<div class="modal">
<h3>🔗 MT5 Webhook Configuration</h3>
<div style="margin-bottom:12px">
<label class="dim" style="display:block;margin-bottom:4px">Webhook URL (your MT5 EA endpoint)</label>
<input type="text" id="webhookUrl" placeholder="http://localhost:5000/webhook">
</div>
<div style="margin-bottom:12px">
<label class="dim" style="display:block;margin-bottom:4px">Secret Key (optional)</label>
<input type="text" id="webhookSecret" placeholder="your-secret-key">
</div>
<div class="grid g2" style="margin-bottom:12px">
<label style="display:flex;align-items:center;gap:4px;cursor:pointer">
<input type="checkbox" id="whOpenEnabled" checked> Send on OPEN
</label>
<label style="display:flex;align-items:center;gap:4px;cursor:pointer">
<input type="checkbox" id="whCloseEnabled" checked> Send on CLOSE
</label>
</div>
<div class="webhook-status" id="webhookTestResult"></div>
<div class="modal-buttons">
<button onclick="testWebhook()">🧪 Test</button>
<button onclick="saveWebhookConfig()">💾 Save</button>
<button onclick="closeWebhookModal()">✕ Close</button>
</div>
</div>
</div>

<script>
// Dark/Light mode
if(matchMedia('(prefers-color-scheme:light)').matches)document.documentElement.classList.add('light');
matchMedia('(prefers-color-scheme:light)').onchange=e=>document.documentElement.classList.toggle('light',e.matches);

// =====================================================
// FOREX INSTRUMENTS (28 pairs)
// =====================================================
const SYM=[
  // Major Pairs
  {s:'EUR/USD',base:'EUR',quote:'USD',p:0.0001,t:'major',mt5:'EURUSD',spread:1.2},
  {s:'GBP/USD',base:'GBP',quote:'USD',p:0.0001,t:'major',mt5:'GBPUSD',spread:1.5},
  {s:'USD/JPY',base:'USD',quote:'JPY',p:0.01,t:'major',mt5:'USDJPY',spread:1.3},
  {s:'USD/CHF',base:'USD',quote:'CHF',p:0.0001,t:'major',mt5:'USDCHF',spread:1.8},
  {s:'AUD/USD',base:'AUD',quote:'USD',p:0.0001,t:'major',mt5:'AUDUSD',spread:1.4},
  {s:'USD/CAD',base:'USD',quote:'CAD',p:0.0001,t:'major',mt5:'USDCAD',spread:1.6},
  {s:'NZD/USD',base:'NZD',quote:'USD',p:0.0001,t:'major',mt5:'NZDUSD',spread:1.8},
  
  // Euro Crosses
  {s:'EUR/GBP',base:'EUR',quote:'GBP',p:0.0001,t:'cross',mt5:'EURGBP',spread:1.5},
  {s:'EUR/JPY',base:'EUR',quote:'JPY',p:0.01,t:'cross',mt5:'EURJPY',spread:1.8},
  {s:'EUR/CHF',base:'EUR',quote:'CHF',p:0.0001,t:'cross',mt5:'EURCHF',spread:2.0},
  {s:'EUR/AUD',base:'EUR',quote:'AUD',p:0.0001,t:'cross',mt5:'EURAUD',spread:2.5},
  {s:'EUR/CAD',base:'EUR',quote:'CAD',p:0.0001,t:'cross',mt5:'EURCAD',spread:2.2},
  {s:'EUR/NZD',base:'EUR',quote:'NZD',p:0.0001,t:'cross',mt5:'EURNZD',spread:3.0},
  
  // GBP Crosses
  {s:'GBP/JPY',base:'GBP',quote:'JPY',p:0.01,t:'cross',mt5:'GBPJPY',spread:2.5},
  {s:'GBP/CHF',base:'GBP',quote:'CHF',p:0.0001,t:'cross',mt5:'GBPCHF',spread:2.8},
  {s:'GBP/AUD',base:'GBP',quote:'AUD',p:0.0001,t:'cross',mt5:'GBPAUD',spread:3.0},
  {s:'GBP/CAD',base:'GBP',quote:'CAD',p:0.0001,t:'cross',mt5:'GBPCAD',spread:2.8},
  {s:'GBP/NZD',base:'GBP',quote:'NZD',p:0.0001,t:'cross',mt5:'GBPNZD',spread:3.5},
  
  // Other Crosses
  {s:'AUD/JPY',base:'AUD',quote:'JPY',p:0.01,t:'cross',mt5:'AUDJPY',spread:2.0},
  {s:'AUD/NZD',base:'AUD',quote:'NZD',p:0.0001,t:'cross',mt5:'AUDNZD',spread:2.5},
  {s:'AUD/CAD',base:'AUD',quote:'CAD',p:0.0001,t:'cross',mt5:'AUDCAD',spread:2.2},
  {s:'AUD/CHF',base:'AUD',quote:'CHF',p:0.0001,t:'cross',mt5:'AUDCHF',spread:2.5},
  {s:'NZD/JPY',base:'NZD',quote:'JPY',p:0.01,t:'cross',mt5:'NZDJPY',spread:2.5},
  {s:'NZD/CAD',base:'NZD',quote:'CAD',p:0.0001,t:'cross',mt5:'NZDCAD',spread:2.8},
  {s:'NZD/CHF',base:'NZD',quote:'CHF',p:0.0001,t:'cross',mt5:'NZDCHF',spread:3.0},
  {s:'CAD/JPY',base:'CAD',quote:'JPY',p:0.01,t:'cross',mt5:'CADJPY',spread:2.2},
  {s:'CAD/CHF',base:'CAD',quote:'CHF',p:0.0001,t:'cross',mt5:'CADCHF',spread:2.5},
  
  // Gold
  {s:'XAU/USD',base:'XAU',quote:'USD',p:0.01,t:'metal',mt5:'XAUUSD',spread:25}
];

// Enhanced Config - Conservative Forex HFT
const C={
  start:100,
  baseLot:0.01,
  tp:15,           // 15 pip TP (3:1 RR)
  sl:5,            // 5 pip SL tight
  trail:6,         // Trail after 6 pips
  maxPos:6,        // Max 6 positions
  maxDD:5,         // 5% max drawdown circuit breaker
  dailyLossLimit:3,// 3% daily loss limit
  cooldown:5000,   // 5s cooldown for forex
  rsiPeriod:14,
  minRSI:25,       // Oversold
  maxRSI:75,       // Overbought
  minStrength:3,   // Need 3+ strategy confirmations
  spreadMax:3,     // Max 3 pip spread to enter
  corrThreshold:0.7
};

// =====================================================
// WEBHOOK CONFIGURATION FOR MT5
// =====================================================
let webhookConfig = {
  url: '',
  secret: '',
  openEnabled: true,
  closeEnabled: true,
  lastStatus: null,
  sentCount: 0,
  errorCount: 0
};

function loadWebhookConfig() {
  try {
    const hash = location.hash.slice(1);
    if (hash) {
      const data = JSON.parse(atob(hash));
      if (data.webhook) {
        webhookConfig = { ...webhookConfig, ...data.webhook };
      }
    }
  } catch (e) {
    console.log('No webhook config found');
  }
  updateWebhookUI();
}

function saveWebhookConfig() {
  webhookConfig.url = document.getElementById('webhookUrl').value.trim();
  webhookConfig.secret = document.getElementById('webhookSecret').value.trim();
  webhookConfig.openEnabled = document.getElementById('whOpenEnabled').checked;
  webhookConfig.closeEnabled = document.getElementById('whCloseEnabled').checked;
  
  save();
  updateWebhookUI();
  closeWebhookModal();
  log('🔗 Webhook config saved', 'b');
}

function updateWebhookUI() {
  const el = document.getElementById('webhook');
  if (webhookConfig.url) {
    el.textContent = 'WH:✓';
    el.className = 'badge on';
  } else {
    el.textContent = 'WH:OFF';
    el.className = 'badge dim';
  }
}

function showWebhookConfig() {
  document.getElementById('webhookUrl').value = webhookConfig.url;
  document.getElementById('webhookSecret').value = webhookConfig.secret;
  document.getElementById('whOpenEnabled').checked = webhookConfig.openEnabled;
  document.getElementById('whCloseEnabled').checked = webhookConfig.closeEnabled;
  document.getElementById('webhookModal').style.display = 'flex';
}

function closeWebhookModal() {
  document.getElementById('webhookModal').style.display = 'none';
}

function generateTradeId() {
  return 'HFT-' + Date.now().toString(36).toUpperCase() + '-' + Math.random().toString(36).substring(2, 6).toUpperCase();
}

// =====================================================
// WEBHOOK SENDER - MT5 INTEGRATION
// =====================================================
async function sendWebhook(action, tradeData) {
  if (!webhookConfig.url) return;
  if (action === 'OPEN' && !webhookConfig.openEnabled) return;
  if (action === 'CLOSE' && !webhookConfig.closeEnabled) return;

  const symData = SYM.find(s => s.s === tradeData.sym);
  
  const payload = {
    action: action,
    source: "HFT-ULTRA-FX-2026",
    version: "1.0",
    timestamp: new Date().toISOString(),
    timestamp_unix: Date.now(),
    trade_id: tradeData.id || generateTradeId(),
    symbol: tradeData.sym,
    symbol_mt5: symData?.mt5 || tradeData.sym.replace('/', ''),
    direction: tradeData.type,
    order_type: tradeData.type === 'BUY' ? 0 : 1,
    entry_price: tradeData.entry,
    current_price: tradeData.currentPrice || tradeData.entry,
    take_profit: tradeData.tp,
    stop_loss: tradeData.sl,
    trailing_stop: tradeData.trail || null,
    lot_size: tradeData.lot,
    pip_value: tradeData.pipValue,
    pip_size: tradeData.pip,
    signal_strength: tradeData.strength || 0,
    exit_price: action === 'CLOSE' ? tradeData.exitPrice : null,
    exit_reason: action === 'CLOSE' ? tradeData.reason : null,
    pnl_pips: action === 'CLOSE' ? tradeData.pips : null,
    pnl_usd: action === 'CLOSE' ? tradeData.pnl : null,
    duration_ms: action === 'CLOSE' ? (Date.now() - tradeData.time) : null,
    account: {
      balance: S.bal,
      equity: S.bal + getUnrealized(),
      open_positions: S.pos.length,
      total_trades: S.wins + S.losses,
      win_rate: S.wins + S.losses > 0 ? (S.wins / (S.wins + S.losses) * 100).toFixed(2) : 0
    },
    auth: webhookConfig.secret ? {
      secret: webhookConfig.secret,
      signature: btoa(webhookConfig.secret + ':' + Date.now())
    } : null
  };

  try {
    const response = await fetch(webhookConfig.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Signal-Source': 'HFT-ULTRA-FX-2026',
        'X-Signal-Action': action,
        ...(webhookConfig.secret && { 'X-Auth-Key': webhookConfig.secret })
      },
      body: JSON.stringify(payload),
      mode: 'cors'
    });

    if (response.ok) {
      webhookConfig.sentCount++;
      webhookConfig.lastStatus = 'OK';
      log(`🔗 WH ${action}: ${tradeData.sym}`, 'b');
    } else {
      throw new Error(`HTTP ${response.status}`);
    }
  } catch (err) {
    webhookConfig.errorCount++;
    webhookConfig.lastStatus = 'ERR';
    console.log('Webhook error:', JSON.stringify(err.message));
    if (webhookConfig.errorCount <= 3) {
      log(`⚠️ WH Error: ${err.message}`, 'y');
    }
  }
}

async function testWebhook() {
  const url = document.getElementById('webhookUrl').value.trim();
  const resultEl = document.getElementById('webhookTestResult');
  
  if (!url) {
    resultEl.innerHTML = '<span class="r">❌ Please enter a webhook URL</span>';
    return;
  }

  resultEl.innerHTML = '<span class="y">🔄 Testing...</span>';

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Signal-Source': 'HFT-ULTRA-FX-2026',
        'X-Signal-Action': 'TEST'
      },
      body: JSON.stringify({
        action: 'TEST',
        source: 'HFT-ULTRA-FX-2026',
        version: '1.0',
        timestamp: new Date().toISOString(),
        message: 'Connection test from HFT Ultra FX 2026'
      }),
      mode: 'cors'
    });

    if (response.ok) {
      resultEl.innerHTML = '<span class="g">✅ Connection successful!</span>';
    } else {
      resultEl.innerHTML = `<span class="r">❌ HTTP Error: ${response.status}</span>`;
    }
  } catch (err) {
    resultEl.innerHTML = `<span class="r">❌ ${err.message}</span>`;
  }
}

// State
let S=load()||fresh();
let prices={},history={},lastTrade={},logs=[],ticks=0,dailyPnL=0,dayStart=new Date().toDateString();
let ecbRates={};

function fresh(){return{bal:C.start,pos:[],wins:0,losses:0,grossWin:0,grossLoss:0,eq:[C.start],streak:0,best:C.start,peak:C.start,returns:[]}}

function load(){
  try{
    const data = JSON.parse(atob(location.hash.slice(1)));
    if (data.webhook) {
      webhookConfig = { ...webhookConfig, ...data.webhook };
    }
    return data;
  } catch(e) {
    return null;
  }
}

function save(){
  try{
    const data = {
      ...S,
      eq: S.eq.slice(-60),
      returns: S.returns.slice(-100),
      webhook: {
        url: webhookConfig.url,
        secret: webhookConfig.secret,
        openEnabled: webhookConfig.openEnabled,
        closeEnabled: webhookConfig.closeEnabled
      }
    };
    history.replaceState(null, '', '#' + btoa(JSON.stringify(data)));
  } catch(e) {}
}

function reset(){S=fresh();logs=[];prices={};history={};dailyPnL=0;ecbRates={};save();render()}

// =====================================================
// FOREX PRICE DATA - ECB + Simulated Ticks
// =====================================================

// Fetch ECB rates via Frankfurter API (free, CORS enabled)
async function fetchECBRates(){
  try{
    // Fetch latest rates from ECB via Frankfurter
    const r = await fetch('https://api.frankfurter.app/latest?from=USD');
    const data = await r.json();
    
    // Store rates (all vs USD)
    ecbRates = {
      'USD': 1,
      'EUR': 1 / data.rates.EUR, // EUR/USD
      'GBP': 1 / data.rates.GBP, // GBP/USD
      'JPY': data.rates.JPY,     // USD/JPY
      'CHF': data.rates.CHF,     // USD/CHF
      'AUD': 1 / data.rates.AUD, // AUD/USD
      'CAD': data.rates.CAD,     // USD/CAD
      'NZD': 1 / data.rates.NZD, // NZD/USD
    };
    
    // Also fetch XAU (gold) - use approximate market rate
    // ECB doesn't provide gold, so we'll simulate around ~2650
    ecbRates['XAU'] = 2650 + (Math.random() - 0.5) * 20;
    
    document.getElementById('api').textContent='API:ECB✓';
    document.getElementById('api').className='badge on';
    return true;
  }catch(e){
    console.log('ECB API error:', JSON.stringify(e));
    // Use fallback rates if API fails
    ecbRates = {
      'USD': 1,
      'EUR': 1.0850,
      'GBP': 1.2650,
      'JPY': 149.50,
      'CHF': 0.8850,
      'AUD': 0.6550,
      'CAD': 1.3550,
      'NZD': 0.6150,
      'XAU': 2650
    };
    document.getElementById('api').textContent='API:SIM';
    document.getElementById('api').className='badge warn';
    return true;
  }
}

// Calculate cross rate from base rates
function getCrossRate(base, quote) {
  if (base === 'USD') {
    return ecbRates[quote] || 1;
  } else if (quote === 'USD') {
    return ecbRates[base] || 1;
  } else {
    // Cross rate: BASE/QUOTE = (BASE/USD) / (QUOTE/USD)
    const baseUSD = ecbRates[base] || 1;
    const quoteUSD = ecbRates[quote] || 1;
    
    // Handle JPY pairs
    if (quote === 'JPY') {
      return baseUSD * ecbRates['JPY'];
    }
    if (base === 'JPY') {
      return 1 / (quoteUSD * ecbRates['JPY']);
    }
    
    return baseUSD / quoteUSD;
  }
}

// Simulate realistic forex tick movement
function simulateTick(sym, basePrice) {
  const pip = sym.p;
  const volatility = sym.t === 'metal' ? 0.5 : (sym.t === 'major' ? 0.3 : 0.4);
  
  // Random walk with slight mean reversion
  const change = (Math.random() - 0.5) * volatility * pip * 10;
  
  return basePrice + change;
}

// Update prices with simulated ticks
function updatePrices(){
  SYM.forEach(sym => {
    // Calculate base mid price from ECB rates
    let baseMid = getCrossRate(sym.base, sym.quote);
    
    // Add simulated tick movement
    const prevMid = prices[sym.s]?.mid || baseMid;
    const newMid = simulateTick(sym, prevMid);
    
    // Mean reversion toward ECB rate
    const reversion = (baseMid - newMid) * 0.01;
    const mid = newMid + reversion;
    
    updateHistory(sym.s, mid);
    
    // Calculate bid/ask with spread
    const spreadPips = sym.spread * (0.8 + Math.random() * 0.4); // Variable spread
    const halfSpread = (spreadPips * sym.p) / 2;
    
    const bid = mid - halfSpread;
    const ask = mid + halfSpread;
    const change = prices[sym.s] ? (mid - prices[sym.s].mid) / sym.p : 0;
    
    prices[sym.s] = {
      bid: bid,
      ask: ask,
      mid: mid,
      change: change,
      spread: spreadPips,
      pip: sym.p,
      type: sym.t
    };
  });
  ticks++;
}

// Price history for indicators
function updateHistory(sym, price){
  if(!history[sym]) history[sym] = [];
  history[sym].push(price);
  if(history[sym].length > 50) history[sym].shift();
}

// RSI Calculation
function calcRSI(sym){
  const h = history[sym];
  if(!h || h.length < C.rsiPeriod + 1) return 50;
  let gains = 0, losses = 0;
  for(let i = h.length - C.rsiPeriod; i < h.length; i++){
    const diff = h[i] - h[i-1];
    if(diff > 0) gains += diff;
    else losses -= diff;
  }
  if(losses === 0) return 100;
  const rs = gains / losses;
  return 100 - (100 / (1 + rs));
}

// Momentum (Rate of Change)
function calcMomentum(sym){
  const h = history[sym];
  if(!h || h.length < 10) return 0;
  return ((h[h.length-1] - h[h.length-10]) / h[h.length-10]) * 100;
}

// Volatility
function calcVolatility(sym){
  const h = history[sym];
  if(!h || h.length < 10) return 1;
  let sum = 0;
  for(let i = 1; i < Math.min(h.length, 10); i++){
    sum += Math.abs(h[i] - h[i-1]);
  }
  return sum / 9;
}

// Forex correlation pairs
function getCorrelatedPairs(sym){
  const corr = {
    'EUR/USD': ['GBP/USD', 'EUR/GBP'],
    'GBP/USD': ['EUR/USD', 'EUR/GBP'],
    'USD/JPY': ['EUR/JPY', 'GBP/JPY'],
    'EUR/JPY': ['USD/JPY', 'GBP/JPY'],
    'GBP/JPY': ['USD/JPY', 'EUR/JPY'],
    'AUD/USD': ['NZD/USD', 'AUD/NZD'],
    'NZD/USD': ['AUD/USD', 'AUD/NZD'],
    'USD/CHF': ['EUR/CHF', 'EUR/USD'],
    'USD/CAD': ['AUD/CAD', 'EUR/CAD'],
    'XAU/USD': ['EUR/USD'] // Gold correlates with EUR
  };
  return corr[sym] || [];
}

// Enhanced AI Signal Generation for Forex
function getSignal(sym){
  const p = prices[sym];
  if(!p) return {score: 0, strength: 0, sig: null, rsi: 50, mom: 0};

  const rsi = calcRSI(sym);
  const mom = calcMomentum(sym);
  const vol = calcVolatility(sym);

  let score = 0, strength = 0;

  // 1. RSI Strategy
  if(rsi < C.minRSI) { score += 20; strength++; }
  else if(rsi > C.maxRSI) { score -= 20; strength++; }
  else if(rsi < 40) { score += 10; }
  else if(rsi > 60) { score -= 10; }

  // 2. Momentum Confirmation
  if(mom > 0.02 && rsi < 50) { score += 15; strength++; }
  else if(mom < -0.02 && rsi > 50) { score -= 15; strength++; }

  // 3. Trend Following (MA)
  const h = history[sym];
  if(h && h.length >= 20){
    const ma20 = h.slice(-20).reduce((a,b) => a + b, 0) / 20;
    if(p.mid > ma20 && mom > 0) { score += 12; strength++; }
    else if(p.mid < ma20 && mom < 0) { score -= 12; strength++; }
  }

  // 4. Volatility Filter
  if(vol < p.mid * 0.0005) { strength++; }

  // 5. USD strength check (for USD pairs)
  if(sym.includes('USD')){
    const eurusd = prices['EUR/USD'];
    if(eurusd){
      if(sym.startsWith('USD') && eurusd.change < 0) { strength++; } // USD strong
      else if(sym.endsWith('USD') && eurusd.change > 0) { strength++; } // USD weak
    }
  }

  // 6. Cross-pair confirmation
  const corr = getCorrelatedPairs(sym);
  corr.forEach(c => {
    const cp = prices[c];
    if(cp){
      if((score > 0 && cp.change > 0) || (score < 0 && cp.change < 0)) strength++;
    }
  });

  // Spread filter
  if(p.spread > C.spreadMax) return {score, strength: 0, sig: null, rsi: Math.round(rsi), mom: mom.toFixed(3)};

  let sig = null;
  if(score >= 25 && strength >= C.minStrength) sig = 'BUY';
  else if(score <= -25 && strength >= C.minStrength) sig = 'SELL';

  return {score, strength, sig, rsi: Math.round(rsi), mom: mom.toFixed(3)};
}

// Risk Shield
function checkRiskShield(){
  const equity = S.bal + getUnrealized();
  const dd = (S.peak - equity) / S.peak * 100;
  const heat = (S.pos.length / C.maxPos) * 100;

  if(new Date().toDateString() !== dayStart){
    dayStart = new Date().toDateString();
    dailyPnL = 0;
  }

  document.getElementById('dd').textContent = dd.toFixed(1) + '%';
  document.getElementById('heat').textContent = Math.round(heat) + '%';
  document.getElementById('dailyLoss').textContent = '$' + dailyPnL.toFixed(2);
  document.getElementById('heat').className = heat > 70 ? 'r' : heat > 50 ? 'y' : 'g';

  if(dd >= C.maxDD){
    document.getElementById('shield').textContent = 'SHIELD:🛑';
    document.getElementById('shield').className = 'badge off';
    return false;
  }
  if(Math.abs(dailyPnL) >= C.start * (C.dailyLossLimit / 100) && dailyPnL < 0){
    document.getElementById('shield').textContent = 'SHIELD:⚠️';
    document.getElementById('shield').className = 'badge warn';
    return false;
  }

  document.getElementById('shield').textContent = 'SHIELD:✓';
  document.getElementById('shield').className = 'badge on';
  return true;
}

// Dynamic lot sizing
function calcLotSize(sym){
  const vol = calcVolatility(sym);
  const p = prices[sym];
  const volFactor = p ? Math.max(0.5, 1 - vol / p.mid * 100) : 1;
  const streakFactor = S.streak < -2 ? 0.5 : 1;
  const lot = Math.max(0.01, Math.min(0.05, C.baseLot * volFactor * streakFactor));
  document.getElementById('lotSize').textContent = lot.toFixed(2);
  return lot;
}

function getUnrealized(){
  let u = 0;
  S.pos.forEach(pos => {
    const p = prices[pos.sym];
    if(!p) return;
    const cur = pos.type === 'BUY' ? p.bid : p.ask;
    const pips = pos.type === 'BUY' ? (cur - pos.entry) / pos.pip : (pos.entry - cur) / pos.pip;
    u += pips * pos.pipValue;
  });
  return u;
}

function hasCorrelatedPosition(sym){
  const corr = getCorrelatedPairs(sym);
  return S.pos.some(p => corr.includes(p.sym) || p.sym === sym);
}

// Trading Engine
function trade(){
  if(!checkRiskShield()) return;

  const now = Date.now();

  SYM.forEach(sym => {
    const p = prices[sym.s];
    if(!p) return;

    if(lastTrade[sym.s] && now - lastTrade[sym.s] < C.cooldown) return;
    if(hasCorrelatedPosition(sym.s)) return;
    if(S.pos.length >= C.maxPos) return;

    const {sig, strength} = getSignal(sym.s);

    if(sig){
      const lot = calcLotSize(sym.s);
      // Pip value for forex: 0.01 lot = $0.10 per pip (for most pairs)
      const pipValue = lot * (sym.s.includes('JPY') ? 100 : 10);

      const isBuy = sig === 'BUY';
      const entry = isBuy ? p.ask : p.bid;
      const tradeId = generateTradeId();

      const newPos = {
        id: tradeId,
        sym: sym.s,
        type: sig,
        entry,
        tp: isBuy ? entry + C.tp * sym.p : entry - C.tp * sym.p,
        sl: isBuy ? entry - C.sl * sym.p : entry + C.sl * sym.p,
        trail: null,
        pipValue,
        pip: sym.p,
        lot,
        strength,
        time: now
      };

      S.pos.push(newPos);
      sendWebhook('OPEN', newPos);
      lastTrade[sym.s] = now;
      log(`📈 ${sig} ${sym.s} @${fmtP(sym.s, entry)} [${strength}★]`, isBuy ? 'g' : 'r');
      save();
    }
  });

  managePositions();
}

function managePositions(){
  const toClose = [];

  S.pos.forEach((pos, i) => {
    const p = prices[pos.sym];
    if(!p) return;

    const isBuy = pos.type === 'BUY';
    const cur = isBuy ? p.bid : p.ask;
    const pips = isBuy ? (cur - pos.entry) / pos.pip : (pos.entry - cur) / pos.pip;

    if(pips >= C.trail && !pos.trail){
      pos.trail = cur;
      log(`🔒 TRAIL ${pos.sym} +${pips.toFixed(1)}p`, 'y');
    }

    if(pos.trail){
      if(isBuy && cur > pos.trail){
        pos.trail = cur;
        pos.sl = cur - C.trail * pos.pip * 0.4;
      } else if(!isBuy && cur < pos.trail){
        pos.trail = cur;
        pos.sl = cur + C.trail * pos.pip * 0.4;
      }
    }

    let reason = null;
    if(isBuy){
      if(cur >= pos.tp) reason = 'TP';
      else if(cur <= pos.sl) reason = pos.trail ? 'TRAIL' : 'SL';
    } else {
      if(cur <= pos.tp) reason = 'TP';
      else if(cur >= pos.sl) reason = pos.trail ? 'TRAIL' : 'SL';
    }

    if(reason){
      const pnl = pips * pos.pipValue;
      S.bal += pnl;
      dailyPnL += pnl;

      S.returns.push(pnl / C.start * 100);
      if(S.returns.length > 100) S.returns.shift();

      if(pnl > 0){
        S.wins++; S.grossWin += pnl;
        S.streak = S.streak > 0 ? S.streak + 1 : 1;
      } else {
        S.losses++; S.grossLoss += Math.abs(pnl);
        S.streak = S.streak < 0 ? S.streak - 1 : -1;
      }

      if(S.bal > S.best) S.best = S.bal;
      if(S.bal > S.peak) S.peak = S.bal;

      sendWebhook('CLOSE', {
        ...pos,
        exitPrice: cur,
        currentPrice: cur,
        reason: reason,
        pips: pips,
        pnl: pnl
      });

      const em = reason === 'TP' ? '✅' : reason === 'TRAIL' ? '🔒' : '❌';
      log(`${em} ${reason} ${pos.sym} ${pnl >= 0 ? '+' : ''}$${pnl.toFixed(2)}`, pnl >= 0 ? 'g' : 'r');
      toClose.push(i);
    }
  });

  if(toClose.length){
    S.pos = S.pos.filter((_, i) => !toClose.includes(i));
    save();
  }
}

function calcSharpe(){
  if(S.returns.length < 10) return 0;
  const mean = S.returns.reduce((a, b) => a + b, 0) / S.returns.length;
  const variance = S.returns.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / S.returns.length;
  const std = Math.sqrt(variance);
  return std === 0 ? 0 : (mean / std * Math.sqrt(252)).toFixed(2);
}

function log(msg, cls){
  logs.unshift({msg, cls, t: Date.now()});
  if(logs.length > 20) logs.pop();
}

function fmtP(sym, price){
  const s = SYM.find(x => x.s === sym);
  if(!s) return price.toFixed(4);
  if(s.p >= 0.01) return price.toFixed(2);
  return price.toFixed(5);
}

function render(){
  const unr = getUnrealized();
  const equity = S.bal + unr;
  const pnl = equity - C.start;
  const pct = (pnl / C.start) * 100;
  const total = S.wins + S.losses;
  const wr = total > 0 ? Math.round(S.wins / total * 100) : 0;
  const pf = S.grossLoss > 0 ? (S.grossWin / S.grossLoss).toFixed(2) : '∞';

  document.getElementById('equity').textContent = '$' + equity.toFixed(2);
  document.getElementById('equity').className = pnl >= 0 ? 'g' : 'r';
  document.getElementById('pnl').textContent = (pnl >= 0 ? '+' : '') + pnl.toFixed(2);
  document.getElementById('pnl').className = pnl >= 0 ? 'g' : 'r';
  document.getElementById('pnlPct').textContent = (pnl >= 0 ? '+' : '') + pct.toFixed(2) + '%';
  document.getElementById('pnlPct').className = pnl >= 0 ? 'g' : 'r';
  document.getElementById('trades').textContent = total;
  document.getElementById('winrate').textContent = wr + '%';
  document.getElementById('winrate').className = wr >= 50 ? 'g' : wr >= 40 ? 'y' : 'r';
  document.getElementById('pf').textContent = pf;
  document.getElementById('openPos').textContent = S.pos.length + '/' + C.maxPos;
  document.getElementById('streak').textContent = (S.streak > 0 ? '+' : '') + S.streak;
  document.getElementById('streak').className = S.streak > 0 ? 'g' : S.streak < 0 ? 'r' : '';
  document.getElementById('best').textContent = '$' + S.best.toFixed(2);
  document.getElementById('avgWin').textContent = '$' + (S.wins > 0 ? (S.grossWin / S.wins).toFixed(2) : '0');
  document.getElementById('avgLoss').textContent = '$' + (S.losses > 0 ? (S.grossLoss / S.losses).toFixed(2) : '0');
  document.getElementById('sharpe').textContent = calcSharpe();
  document.getElementById('time').textContent = new Date().toLocaleTimeString();
  document.getElementById('status').textContent = '🟢 LIVE';
  document.getElementById('status').className = 'badge on';

  // Market table
  document.getElementById('market').innerHTML = SYM.map(sym => {
    const p = prices[sym.s];
    if(!p) return '';
    const {strength, sig, rsi, mom} = getSignal(sym.s);
    const pos = S.pos.find(x => x.sym === sym.s);

    let posH = '-';
    if(pos){
      const cur = pos.type === 'BUY' ? p.bid : p.ask;
      const pips = pos.type === 'BUY' ? (cur - pos.entry) / pos.pip : (pos.entry - cur) / pos.pip;
      const pnl = pips * pos.pipValue;
      posH = `<span class="${pnl >= 0 ? 'g' : 'r'}">${pnl >= 0 ? '+' : ''}$${pnl.toFixed(2)}</span>`;
    }

    let sigH = '-';
    if(sig === 'BUY') sigH = '<span class="g">▲BUY</span>';
    else if(sig === 'SELL') sigH = '<span class="r">▼SELL</span>';

    const rsiC = rsi < 30 ? 'g' : rsi > 70 ? 'r' : 'dim';
    const momC = parseFloat(mom) > 0 ? 'g' : parseFloat(mom) < 0 ? 'r' : 'dim';
    const typeC = sym.t === 'major' ? 'b' : sym.t === 'metal' ? 'y' : 'dim';

    return `<tr>
      <td><b class="${typeC}">${sym.s}</b></td>
      <td>${fmtP(sym.s, p.bid)}</td>
      <td>${fmtP(sym.s, p.ask)}</td>
      <td class="dim">${p.spread.toFixed(1)}</td>
      <td class="${rsiC}">${rsi}</td>
      <td class="${momC}">${mom}</td>
      <td>${sigH}</td>
      <td>${posH}</td>
    </tr>`;
  }).join('');

  // Positions
  if(S.pos.length === 0){
    document.getElementById('positions').innerHTML = '<span class="dim">Scanning markets...</span>';
  } else {
    document.getElementById('positions').innerHTML = S.pos.map(pos => {
      const p = prices[pos.sym];
      if(!p) return '';
      const cur = pos.type === 'BUY' ? p.bid : p.ask;
      const pips = pos.type === 'BUY' ? (cur - pos.entry) / pos.pip : (pos.entry - cur) / pos.pip;
      const pnl = pips * pos.pipValue;
      return `<div class="log" style="border-left:2px solid ${pnl >= 0 ? 'var(--g)' : 'var(--r)'}">
        ${pos.sym} <span class="${pos.type === 'BUY' ? 'g' : 'r'}">${pos.type}</span> ${pos.trail ? '🔒' : ''}
        <span class="${pnl >= 0 ? 'g' : 'r'}">${pips >= 0 ? '+' : ''}${pips.toFixed(1)}p ($${pnl.toFixed(2)})</span>
      </div>`;
    }).join('');
  }

  // Log
  document.getElementById('log').innerHTML = logs.length
    ? logs.slice(0, 12).map(l => `<div class="log ${l.cls}">${l.msg}</div>`).join('')
    : '<span class="dim">Starting...</span>';

  // Chart
  S.eq.push(equity);
  if(S.eq.length > 60) S.eq.shift();
  const min = Math.min(...S.eq) * 0.98;
  const max = Math.max(...S.eq) * 1.02;
  const range = max - min || 1;
  document.getElementById('chart').innerHTML = S.eq.map((v, i) => {
    const h = Math.max(4, ((v - min) / range) * 100);
    const c = v >= C.start ? 'var(--g)' : 'var(--r)';
    const o = 0.3 + (i / S.eq.length) * 0.7;
    return `<div style="height:${h}%;background:${c};opacity:${o}"></div>`;
  }).join('');
}

// Init
async function init(){
  loadWebhookConfig();
  log('🚀 HFT ULTRA FX 2026 Starting...', 'b');
  log('📡 Fetching ECB forex rates...', 'b');

  const ok = await fetchECBRates();
  if(ok){
    updatePrices();
    render();
    log('✅ Ready! 28 forex pairs loaded', 'g');
    log('🛡️ Risk Shield ACTIVE', 'y');
    if(webhookConfig.url){
      log('🔗 MT5 Webhook ENABLED', 'b');
    }
  } else {
    log('❌ Failed to fetch rates', 'r');
  }

  // Refresh ECB rates every 5 minutes
  setInterval(fetchECBRates, 300000);

  // Main loop - simulate ticks every 1 second
  setInterval(() => {
    updatePrices();
    trade();
    render();
  }, 1000);

  setInterval(save, 5000);
}

init();
</script>
</body>
</html>
