import os, json, time, secrets, sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from flask import Flask, request, jsonify
from flask_cors import CORS
from itsdangerous import URLSafeTimedSerializer, BadSignature, SignatureExpired
from werkzeug.security import generate_password_hash, check_password_hash

app=Flask(__name__)
app.config["SECRET_KEY"]=os.getenv("SECRET_KEY","dev-only-change-me")
CORS(app, origins=os.getenv("CORS_ORIGINS","*").split(","))
signer=URLSafeTimedSerializer(app.config["SECRET_KEY"],salt="fw-auth")
DB_URL=os.getenv("DATABASE_URL","").strip()
DB_FILE=os.getenv("SQLITE_PATH","forgotten_world.db")

@contextmanager
def db():
    if DB_URL:
        import psycopg
        conn=psycopg.connect(DB_URL)
    else:
        conn=sqlite3.connect(DB_FILE); conn.row_factory=sqlite3.Row
    try:
        yield conn; conn.commit()
    except Exception:
        conn.rollback(); raise
    finally: conn.close()

def sql(q): return q.replace("?","%s") if DB_URL else q
def init_db():
    schema=[
    "CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, username TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL, created_at TEXT NOT NULL, banned INTEGER NOT NULL DEFAULT 0, ban_reason TEXT)",
    "CREATE TABLE IF NOT EXISTS worlds (id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL, hosting TEXT NOT NULL, data TEXT NOT NULL DEFAULT '{}', updated_at TEXT NOT NULL)",
    "CREATE TABLE IF NOT EXISTS demo_sessions (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, started_at REAL NOT NULL, completed INTEGER NOT NULL DEFAULT 0)"]
    with db() as c:
        cur=c.cursor()
        for q in schema: cur.execute(q)

def asdict(row):
    if row is None: return None
    return dict(row) if not isinstance(row,dict) else row

def auth():
    h=request.headers.get("Authorization","")
    if not h.startswith("Bearer "): return None
    try: p=signer.loads(h[7:],max_age=60*60*24*30)
    except (BadSignature,SignatureExpired): return None
    with db() as c:
        cur=c.cursor(); cur.execute(sql("SELECT * FROM users WHERE id=?"),(p.get("uid"),))
        return asdict(cur.fetchone())

def player():
    u=auth()
    if not u: return None,(jsonify(error="Authentication required"),401)
    if u["banned"]: return None,(jsonify(error="HAHA GET BANNED BUDDY",banned=True,reason=u["ban_reason"]),403)
    return u,None

@app.get("/")
@app.get("/api/health")
def health(): return jsonify(ok=True,service="forgotten-world-api",version="0.1.0")

@app.post("/api/register")
def register():
    b=request.get_json(silent=True) or {}; name=str(b.get("username","")).strip(); pw=str(b.get("password",""))
    if not 3<=len(name)<=24 or not name.replace("_","").isalnum(): return jsonify(error="Username must be 3-24 letters, numbers or underscores"),400
    if len(pw)<8: return jsonify(error="Password must be at least 8 characters"),400
    uid=secrets.token_hex(16); now=datetime.now(timezone.utc).isoformat()
    try:
        with db() as c:
            cur=c.cursor(); cur.execute(sql("INSERT INTO users (id,username,password_hash,created_at) VALUES (?,?,?,?)"),(uid,name,generate_password_hash(pw),now))
    except Exception: return jsonify(error="Username is already taken"),409
    return jsonify(token=signer.dumps({"uid":uid}),user={"id":uid,"username":name}),201

@app.post("/api/login")
def login():
    b=request.get_json(silent=True) or {}
    with db() as c:
        cur=c.cursor(); cur.execute(sql("SELECT * FROM users WHERE username=?"),(str(b.get("username","")).strip(),)); u=asdict(cur.fetchone())
    if not u or not check_password_hash(u["password_hash"],str(b.get("password",""))): return jsonify(error="Invalid username or password"),401
    if u["banned"]: return jsonify(error="HAHA GET BANNED BUDDY",banned=True,reason=u["ban_reason"]),403
    return jsonify(token=signer.dumps({"uid":u["id"]}),user={"id":u["id"],"username":u["username"]})

@app.get("/api/me")
def me():
    u,e=player()
    if e:return e
    return jsonify(id=u["id"],username=u["username"],created_at=u["created_at"])

@app.get("/api/worlds")
def worlds():
    u,e=player()
    if e:return e
    with db() as c:
        cur=c.cursor(); cur.execute(sql("SELECT id,owner_id,name,hosting,updated_at FROM worlds WHERE owner_id=? ORDER BY updated_at DESC"),(u["id"],)); rows=cur.fetchall()
    return jsonify(worlds=[asdict(r) for r in rows])

@app.post("/api/worlds")
def create_world():
    u,e=player()
    if e:return e
    b=request.get_json(silent=True) or {}; name=str(b.get("name","New World")).strip()[:40] or "New World"; hosting=b.get("hosting","dedicated")
    if hosting not in ("dedicated","player"):return jsonify(error="hosting must be dedicated or player"),400
    wid=secrets.token_hex(12); now=datetime.now(timezone.utc).isoformat()
    with db() as c:
        cur=c.cursor(); cur.execute(sql("INSERT INTO worlds (id,owner_id,name,hosting,data,updated_at) VALUES (?,?,?,?,?,?)"),(wid,u["id"],name,hosting,"{}",now))
    return jsonify(id=wid,name=name,hosting=hosting,updated_at=now),201

@app.get("/api/worlds/<wid>")
def get_world(wid):
    u,e=player()
    if e:return e
    with db() as c:
        cur=c.cursor(); cur.execute(sql("SELECT * FROM worlds WHERE id=? AND owner_id=?"),(wid,u["id"])); w=asdict(cur.fetchone())
    if not w:return jsonify(error="World not found"),404
    w["data"]=json.loads(w["data"]); return jsonify(w)

@app.put("/api/worlds/<wid>")
def save_world(wid):
    u,e=player()
    if e:return e
    data=(request.get_json(silent=True) or {}).get("data")
    if not isinstance(data,dict):return jsonify(error="data must be a JSON object"),400
    encoded=json.dumps(data,separators=(",",":"))
    if len(encoded)>1_000_000:return jsonify(error="World save exceeds 1 MB limit"),413
    now=datetime.now(timezone.utc).isoformat()
    with db() as c:
        cur=c.cursor(); cur.execute(sql("UPDATE worlds SET data=?,updated_at=? WHERE id=? AND owner_id=?"),(encoded,now,wid,u["id"]))
        if cur.rowcount==0:return jsonify(error="World not found"),404
    return jsonify(ok=True,updated_at=now)

@app.post("/api/demo-exploit/start")
def demo_start():
    u,e=player()
    if e:return e
    sid=secrets.token_urlsafe(24)
    with db() as c:
        cur=c.cursor(); cur.execute(sql("INSERT INTO demo_sessions (id,user_id,started_at) VALUES (?,?,?)"),(sid,u["id"],time.time()))
    return jsonify(session_id=sid,wait_seconds=180,message="DEMO ONLY: simulated exploit session started")

@app.post("/api/demo-exploit/finish")
def demo_finish():
    u,e=player()
    if e:return e
    sid=str((request.get_json(silent=True) or {}).get("session_id",""))
    with db() as c:
        cur=c.cursor(); cur.execute(sql("SELECT * FROM demo_sessions WHERE id=? AND user_id=? AND completed=0"),(sid,u["id"])); s=asdict(cur.fetchone())
        if not s:return jsonify(error="Demo session not found"),404
        remaining=max(0,180-int(time.time()-s["started_at"]))
        if remaining:return jsonify(error="Demo is still running",remaining_seconds=remaining),425
        cur.execute(sql("UPDATE demo_sessions SET completed=1 WHERE id=?"),(sid,))
        cur.execute(sql("UPDATE users SET banned=1,ban_reason=? WHERE id=?"),("HAHA GET BANNED BUDDY — simulated exploit detected",u["id"]))
    return jsonify(banned=True,message="HAHA GET BANNED BUDDY",reason="This ban affects only this Forgotten World account.")

if __name__=="__main__":
    init_db()
    app.run(host="0.0.0.0",port=int(os.getenv("PORT","8080")))
