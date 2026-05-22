from flask import Flask, render_template, request, make_response, g
from redis import Redis
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import hashlib
import hmac
import os
import socket
import random
import json
import logging
import time

option_a = os.getenv('OPTION_A', "Cats")
option_b = os.getenv('OPTION_B', "Dogs")
hostname = socket.gethostname()

app = Flask(__name__)

HTTP_REQUESTS = Counter(
    'voting_http_requests_total',
    'Total HTTP requests handled by the vote service',
    ['method', 'endpoint', 'status'],
)
HTTP_REQUEST_LATENCY = Histogram(
    'voting_http_request_duration_seconds',
    'HTTP request latency for the vote service',
    ['method', 'endpoint'],
    buckets=(0.05, 0.1, 0.25, 0.5, 1, 2, 5),
)

gunicorn_error_logger = logging.getLogger('gunicorn.error')
app.logger.handlers.extend(gunicorn_error_logger.handlers)
app.logger.setLevel(logging.INFO)

@app.before_request
def start_request_timer():
    g.request_started_at = time.time()

@app.after_request
def record_request_metrics_and_headers(response):
    response.headers.setdefault('X-Content-Type-Options', 'nosniff')
    response.headers.setdefault('X-Frame-Options', 'DENY')
    response.headers.setdefault('Referrer-Policy', 'no-referrer')
    response.headers.setdefault('Permissions-Policy', 'camera=(), microphone=(), geolocation=()')
    response.headers.setdefault(
        'Content-Security-Policy',
        "default-src 'self'; style-src 'self'; img-src 'self' data:; frame-ancestors 'none'; form-action 'self'; base-uri 'self'",
    )

    if request.path != '/metrics':
        response.headers.setdefault('Cache-Control', 'no-store')

    if request.path == '/metrics':
        return response

    endpoint = request.endpoint or 'unknown'
    HTTP_REQUESTS.labels(request.method, endpoint, response.status_code).inc()
    HTTP_REQUEST_LATENCY.labels(request.method, endpoint).observe(
        time.time() - getattr(g, 'request_started_at', time.time())
    )
    return response

def csrf_token_for(voter_id):
    secret = os.getenv('APP_SECRET') or os.getenv('REDIS_PASSWORD') or 'devsecops-voting-dev-secret'
    return hmac.new(secret.encode(), voter_id.encode(), hashlib.sha256).hexdigest()

def get_redis():
    if not hasattr(g, 'redis'):
        g.redis = Redis(
            host=os.getenv("REDIS_HOST", "redis"),
            port=int(os.getenv("REDIS_PORT", "6379")),
            password=os.getenv("REDIS_PASSWORD") or None,
            db=int(os.getenv("REDIS_DB", "0")),
            socket_timeout=5,
            ssl=os.getenv("REDIS_SSL", "false").lower() == "true",
        )
    return g.redis

@app.route("/healthz", methods=["GET"])
def healthz():
    return {"status": "ok", "service": "vote"}, 200

@app.route("/metrics", methods=["GET"])
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route("/", methods=['POST','GET'])
def hello():
    voter_id = request.cookies.get('voter_id')
    if not voter_id:
        voter_id = hex(random.getrandbits(64))[2:-1]

    vote = None

    if request.method == 'POST':
        expected_csrf_token = csrf_token_for(voter_id)
        if not hmac.compare_digest(request.form.get('csrf_token', ''), expected_csrf_token):
            return {"error": "invalid csrf token"}, 400

        redis = get_redis()
        vote = request.form['vote']
        app.logger.info('Received vote for %s', vote)
        data = json.dumps({'voter_id': voter_id, 'vote': vote})
        redis.rpush('votes', data)

    resp = make_response(render_template(
        'index.html',
        option_a=option_a,
        option_b=option_b,
        hostname=hostname,
        vote=vote,
        csrf_token=csrf_token_for(voter_id),
    ))
    resp.set_cookie(
        'voter_id',
        voter_id,
        httponly=True,
        secure=os.getenv("COOKIE_SECURE", "true").lower() == "true",
        samesite=os.getenv("COOKIE_SAMESITE", "Lax"),
    )
    return resp


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80, debug=True, threaded=True)
