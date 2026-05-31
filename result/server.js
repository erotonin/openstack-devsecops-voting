var express = require('express'),
    async = require('async'),
    path = require('path'),
    { Pool } = require('pg'),
    client = require('prom-client'),
    csrf = require('csurf'),
    cookieParser = require('cookie-parser'),
    app = express(),
    server = require('http').Server(app),
    io = require('socket.io')(server);

var port = process.env.PORT || 4000;
var dbConnected = false;

function dbSslModeFromUrl(databaseUrl) {
  var match = (databaseUrl || '').match(/[?&]sslmode=(disable|allow|prefer|require|verify-ca|verify-full)/i);
  return match ? match[1].toLowerCase() : '';
}

function stripDatabaseUrlSslMode(databaseUrl) {
  return (databaseUrl || '').replace(/([?&])sslmode=(disable|allow|prefer|require|verify-ca|verify-full)(&?)/ig, function(match, prefix, mode, suffix) {
    if (prefix === '?' && suffix === '&') {
      return '?';
    }

    if (suffix === '&') {
      return prefix;
    }

    return '';
  }).replace(/[?&]$/, '');
}

function envFlag(name) {
  return (process.env[name] || '').toLowerCase();
}

function dbSslConfig(databaseUrl) {
  var explicitSsl = (process.env.DB_SSL || '').toLowerCase();
  var sslMode = (process.env.DB_SSL_MODE || dbSslModeFromUrl(databaseUrl)).toLowerCase();
  var rejectUnauthorized = envFlag('DB_SSL_REJECT_UNAUTHORIZED');

  if (explicitSsl === 'false' || sslMode === 'disable') {
    return false;
  }

  if (explicitSsl === 'true' || sslMode === 'require' || sslMode === 'verify-ca' || sslMode === 'verify-full') {
    return {
      rejectUnauthorized: rejectUnauthorized ? rejectUnauthorized === 'true' : (sslMode === 'verify-ca' || sslMode === 'verify-full')
    };
  }

  return false;
}

function dbPoolConfig() {
  var databaseUrl = process.env.DATABASE_URL || '';

  if (process.env.DATABASE_URL) {
    return {
      connectionString: stripDatabaseUrlSslMode(databaseUrl),
      ssl: dbSslConfig(databaseUrl)
    };
  }

  return {
    host: process.env.DB_HOST || 'db',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'postgres',
    ssl: dbSslConfig(databaseUrl)
  };
}

client.collectDefaultMetrics({ prefix: 'result_' });
const httpRequestDuration = new client.Histogram({
  name: 'result_http_request_duration_seconds',
  help: 'HTTP request latency for the result service',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.05, 0.1, 0.25, 0.5, 1, 2, 5]
});
const httpRequests = new client.Counter({
  name: 'result_http_requests_total',
  help: 'Total HTTP requests handled by the result service',
  labelNames: ['method', 'route', 'status']
});

io.on('connection', function (socket) {

  socket.emit('message', { text : 'Welcome!' });

  socket.on('subscribe', function (data) {
    socket.join(data.channel);
  });
});

var pool = new Pool(dbPoolConfig());

async.retry(
  {times: 1000, interval: 1000},
  function(callback) {
    pool.connect(function(err, client, done) {
      if (err) {
        dbConnected = false;
        console.error("Waiting for db: " + err.message);
      }
      callback(err, client);
    });
  },
  function(err, client) {
    if (err) {
      return console.error("Giving up");
    }
    console.log("Connected to db");
    dbConnected = true;
    getVotes(client);
  }
);

function getVotes(client) {
  client.query('SELECT vote, COUNT(id) AS count FROM votes GROUP BY vote', [], function(err, result) {
    if (err) {
      dbConnected = false;
      console.error("Error performing query: " + err);
    } else {
      dbConnected = true;
      var votes = collectVotesFromResult(result);
      io.sockets.emit("scores", JSON.stringify(votes));
    }

    setTimeout(function() {getVotes(client) }, 1000);
  });
}

function collectVotesFromResult(result) {
  var votes = {a: 0, b: 0};

  result.rows.forEach(function (row) {
    votes[row.vote] = parseInt(row.count);
  });

  return votes;
}

app.use(cookieParser());
app.use(express.urlencoded({ extended: false, limit: process.env.URLENCODED_LIMIT || '10kb' }));
app.use(csrf({
  cookie: {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.COOKIE_SECURE !== 'false'
  }
}));
app.use(function (_req, res, next) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  res.setHeader(
    'Content-Security-Policy',
    "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self' ws: wss:; img-src 'self' data:; frame-ancestors 'none'; base-uri 'self'"
  );
  res.setHeader('Cache-Control', 'no-store');
  next();
});
app.use(function (req, res, next) {
  if (req.path === '/metrics') {
    return next();
  }

  const endTimer = httpRequestDuration.startTimer();
  res.on('finish', function () {
    const route = req.route && req.route.path ? req.route.path : req.path;
    const labels = { method: req.method, route: route, status: String(res.statusCode) };
    endTimer(labels);
    httpRequests.inc(labels);
  });
  next();
});
app.use(express.static(__dirname + '/views'));

app.use(function (err, _req, res, next) {
  if (err.code !== 'EBADCSRFTOKEN') {
    return next(err);
  }

  res.status(403).json({ error: 'invalid csrf token' });
});

app.get('/healthz', function (req, res) {
  if (!dbConnected) {
    return res.status(503).json({ status: 'error', service: 'result', dependency: 'db' });
  }

  res.status(200).json({ status: 'ok', service: 'result' });
});

app.get('/metrics', async function (req, res) {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

app.get('/', function (req, res) {
  res.sendFile(path.resolve(__dirname + '/views/index.html'));
});

server.listen(port, function () {
  var port = server.address().port;
  console.log('App running on port ' + port);
});
