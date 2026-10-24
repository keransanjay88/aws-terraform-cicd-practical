import json
import logging
import os
import ssl
import time
import urllib.request
import uuid

import boto3
import pymysql
import pymysql.cursors
from flask import Flask, jsonify, redirect, render_template_string, request, url_for

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("app")

REGION = os.environ.get("AWS_REGION", "ap-south-1")
SECRET_NAME = os.environ["SECRET_NAME"]
APP_BUCKET = os.environ["APP_BUCKET"]


# ---------------------------------------------------------------- instance info
_meta = {}


def instance_info():
    """Instance ID and AZ, read with IMDSv2 (token-based)."""
    if _meta:
        return _meta
    try:
        token_req = urllib.request.Request(
            "http://169.254.169.254/latest/api/token",
            method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "300"},
        )
        with urllib.request.urlopen(token_req, timeout=2) as r:
            token = r.read().decode()

        def get(path):
            req = urllib.request.Request(
                "http://169.254.169.254/latest/meta-data/" + path,
                headers={"X-aws-ec2-metadata-token": token},
            )
            with urllib.request.urlopen(req, timeout=2) as r:
                return r.read().decode()

        _meta["instance_id"] = get("instance-id")
        _meta["az"] = get("placement/availability-zone")
    except Exception:
        log.warning("Could not read instance metadata", exc_info=True)
        return {"instance_id": "unknown", "az": "unknown"}
    return _meta


# ---------------------------------------------------------------- secrets
_secret = {"value": None, "fetched": 0.0}
SECRET_TTL_SECONDS = 300


def get_db_credentials():
    """Fetch DB credentials from Secrets Manager (cached for 5 minutes)."""
    now = time.time()
    if _secret["value"] and now - _secret["fetched"] < SECRET_TTL_SECONDS:
        return _secret["value"]
    client = boto3.client("secretsmanager", region_name=REGION)
    response = client.get_secret_value(SecretId=SECRET_NAME)
    _secret["value"] = json.loads(response["SecretString"])
    _secret["fetched"] = now
    return _secret["value"]


# ---------------------------------------------------------------- database
def get_db():
    creds = get_db_credentials()
    # The database enforces TLS. The connection is encrypted; certificate
    # verification is skipped for this demo (see README for the production fix).
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return pymysql.connect(
        host=creds["host"],
        port=int(creds["port"]),
        user=creds["username"],
        password=creds["password"],
        database=creds["dbname"],
        connect_timeout=5,
        read_timeout=5,
        write_timeout=5,
        ssl=ctx,
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )


SCHEMA = [
    """CREATE TABLE IF NOT EXISTS visits (
         id INT AUTO_INCREMENT PRIMARY KEY,
         instance_id VARCHAR(32),
         az VARCHAR(32),
         visited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
       )""",
    """CREATE TABLE IF NOT EXISTS notes (
         id INT AUTO_INCREMENT PRIMARY KEY,
         body VARCHAR(255) NOT NULL,
         instance_id VARCHAR(32),
         created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
       )""",
]
_schema_ready = False


def ensure_schema(conn):
    global _schema_ready
    if _schema_ready:
        return
    with conn.cursor() as cur:
        for statement in SCHEMA:
            cur.execute(statement)
    _schema_ready = True


# ---------------------------------------------------------------- page
PAGE = """
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DevOps Practical</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 0; background: #f4f6f8; color: #1d2733; }
  header { background: #232f3e; color: #fff; padding: 18px 24px; }
  header h1 { margin: 0; font-size: 20px; }
  main { max-width: 860px; margin: 24px auto; padding: 0 16px; }
  .card { background: #fff; border-radius: 8px; padding: 18px 20px; margin-bottom: 16px;
          box-shadow: 0 1px 3px rgba(0,0,0,.08); }
  .card h2 { margin-top: 0; font-size: 16px; }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
  .stat { background: #eef3f8; border-radius: 6px; padding: 12px; }
  .stat b { display: block; font-size: 12px; color: #586574; text-transform: uppercase; }
  .stat span { font-size: 18px; word-break: break-all; }
  .ok { color: #1a7f37; } .bad { color: #c0392b; }
  table { width: 100%; border-collapse: collapse; font-size: 14px; }
  th, td { text-align: left; padding: 6px 8px; border-bottom: 1px solid #e3e8ee; }
  input[type=text] { padding: 8px; width: 65%; border: 1px solid #b9c3cf; border-radius: 4px; }
  button { padding: 8px 14px; border: 0; border-radius: 4px; background: #0972d3; color: #fff; cursor: pointer; }
  .msg { padding: 10px 14px; border-radius: 6px; background: #e6f4ea; margin-bottom: 16px; }
  .msg.fail { background: #fdecea; }
  a { color: #0972d3; }
</style>
</head>
<body>
<header><h1>DevOps Practical: AWS, Terraform and CI/CD</h1></header>
<main>
  {% if msg %}<div class="msg {{ 'fail' if 'fail' in msg else '' }}">{{ msg }}</div>{% endif %}

  <div class="card">
    <h2>Served by</h2>
    <div class="grid">
      <div class="stat"><b>Instance ID</b><span>{{ info.instance_id }}</span></div>
      <div class="stat"><b>Availability Zone</b><span>{{ info.az }}</span></div>
      <div class="stat"><b>Database</b>
        <span class="{{ 'ok' if db_ok else 'bad' }}">{{ 'Connected' if db_ok else 'Unavailable' }}</span></div>
      <div class="stat"><b>Total visits</b><span>{{ visits if visits is not none else '-' }}</span></div>
    </div>
    <p>Refresh the page a few times: the instance and zone change as the load balancer spreads requests.</p>
  </div>

  {% if db_ok %}
  <div class="card">
    <h2>Last 5 visits (read from RDS)</h2>
    <table>
      <tr><th>Instance</th><th>Zone</th><th>Time (UTC)</th></tr>
      {% for v in recent %}
      <tr><td>{{ v.instance_id }}</td><td>{{ v.az }}</td><td>{{ v.visited_at }}</td></tr>
      {% endfor %}
    </table>
  </div>

  <div class="card">
    <h2>Notes (written to RDS)</h2>
    <form method="post" action="{{ url_for('add_note') }}">
      <input type="text" name="body" maxlength="200" placeholder="Write a note" required>
      <button type="submit">Add note</button>
    </form>
    <table>
      <tr><th>Note</th><th>Instance</th><th>Time (UTC)</th></tr>
      {% for n in notes %}
      <tr><td>{{ n.body }}</td><td>{{ n.instance_id }}</td><td>{{ n.created_at }}</td></tr>
      {% endfor %}
    </table>
  </div>
  {% else %}
  <div class="card"><h2>{{ error }}</h2><p>Check <a href="/health/deep">/health/deep</a> for details.</p></div>
  {% endif %}

  <div class="card">
    <h2>S3 and health checks</h2>
    <form method="post" action="{{ url_for('s3_test') }}">
      <button type="submit">Write and read a test file in S3</button>
    </form>
    <p><a href="/health">/health</a> (load balancer check) &middot;
       <a href="/health/deep">/health/deep</a> (secret, database, S3)</p>
  </div>
</main>
</body>
</html>
"""


@app.after_request
def security_headers(resp):
    resp.headers["X-Content-Type-Options"] = "nosniff"
    resp.headers["X-Frame-Options"] = "DENY"
    resp.headers["Referrer-Policy"] = "no-referrer"
    return resp


@app.route("/")
def index():
    info = instance_info()
    db_ok, visits, recent, notes, error = False, None, [], [], None
    try:
        conn = get_db()
        try:
            ensure_schema(conn)
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO visits (instance_id, az) VALUES (%s, %s)",
                    (info["instance_id"], info["az"]),
                )
                cur.execute("SELECT COUNT(*) AS n FROM visits")
                visits = cur.fetchone()["n"]
                cur.execute(
                    "SELECT instance_id, az, visited_at FROM visits ORDER BY id DESC LIMIT 5"
                )
                recent = cur.fetchall()
                cur.execute(
                    "SELECT body, instance_id, created_at FROM notes ORDER BY id DESC LIMIT 10"
                )
                notes = cur.fetchall()
            db_ok = True
        finally:
            conn.close()
    except Exception:
        log.exception("Database error on /")
        error = "Database unavailable"

    return render_template_string(
        PAGE,
        info=info,
        db_ok=db_ok,
        visits=visits,
        recent=recent,
        notes=notes,
        error=error,
        msg=request.args.get("msg"),
    )


@app.route("/notes", methods=["POST"])
def add_note():
    body = (request.form.get("body") or "").strip()[:200]
    if not body:
        return redirect(url_for("index", msg="Note was empty"))
    try:
        conn = get_db()
        try:
            ensure_schema(conn)
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO notes (body, instance_id) VALUES (%s, %s)",
                    (body, instance_info()["instance_id"]),
                )
        finally:
            conn.close()
        return redirect(url_for("index", msg="Note saved to RDS"))
    except Exception:
        log.exception("Could not save note")
        return redirect(url_for("index", msg="Could not save note (fail)"))


@app.route("/s3-test", methods=["POST"])
def s3_test():
    key = "uploads/test-{}.txt".format(uuid.uuid4().hex[:8])
    content = "written by {}".format(instance_info()["instance_id"])
    try:
        s3 = boto3.client("s3", region_name=REGION)
        s3.put_object(Bucket=APP_BUCKET, Key=key, Body=content.encode())
        read_back = s3.get_object(Bucket=APP_BUCKET, Key=key)["Body"].read().decode()
        if read_back != content:
            raise ValueError("S3 content mismatch")
        return redirect(url_for("index", msg="S3 write and read OK: " + key))
    except Exception:
        log.exception("S3 test failed")
        return redirect(url_for("index", msg="S3 test failed (fail)"))


@app.route("/health")
def health():
    """Fast liveness check used by the load balancer. Never touches the DB."""
    return jsonify(status="ok"), 200


@app.route("/health/deep")
def health_deep():
    """Checks every dependency. For humans and the pipeline."""
    checks, healthy = {}, True

    try:
        get_db_credentials()
        checks["secrets_manager"] = "ok"
    except Exception:
        log.exception("Deep check: secret")
        checks["secrets_manager"] = "fail"
        healthy = False

    try:
        conn = get_db()
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT 1 AS ok")
                cur.fetchone()
        finally:
            conn.close()
        checks["database"] = "ok"
    except Exception:
        log.exception("Deep check: database")
        checks["database"] = "fail"
        healthy = False

    try:
        boto3.client("s3", region_name=REGION).head_bucket(Bucket=APP_BUCKET)
        checks["s3"] = "ok"
    except Exception:
        log.exception("Deep check: s3")
        checks["s3"] = "fail"
        healthy = False

    info = instance_info()
    return (
        jsonify(
            status="ok" if healthy else "degraded",
            checks=checks,
            instance_id=info["instance_id"],
            az=info["az"],
        ),
        200 if healthy else 503,
    )