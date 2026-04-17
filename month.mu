#!/usr/bin/env python3
# nomadCalendar · main.py · central library
# Importing this file initializes DB and performs cleanup

import os
import sys
import sqlite3
import hashlib
import secrets
from datetime import datetime, date, timedelta
from calendar import monthrange

# ─── Configuration ────────────────────────────────────────────────
storage_path  = "/home/user/.nomadCalendar"   # ← customize!
page_path     = ":/page/calendar"
site_name        = "nomadCalendar"
site_description = "Community calendar for events & meetups"  # Short description
node_homepage = ":/page/index.mu"

CALENDAR_YEAR = datetime.now().year           # current year
EXTRA_MONTHS  = 3                             # + months into next year
ARCHIVE_DAYS  = 90                            # 3 months archive
SESSION_TTL   = 6 * 3600                      # admin session 6h

# ─── Database path ────────────────────────────────────────────────
DB_PATH = os.path.join(storage_path, "calendar.db")

def get_db():
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    return c

# ─── Initialize DB ────────────────────────────────────────────────
def init_db():
    os.makedirs(storage_path, exist_ok=True)
    c = get_db()
    cur = c.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS events (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            title       TEXT NOT NULL,
            body        TEXT DEFAULT '',
            category    TEXT DEFAULT 'diverses',
            start_dt    TEXT NOT NULL,
            end_dt      TEXT DEFAULT '',
            location    TEXT DEFAULT '',
            lxmf        TEXT DEFAULT '',
            contact     TEXT DEFAULT '',
            edit_token  TEXT NOT NULL,
            is_approved INTEGER DEFAULT 1,
            created_at  TEXT NOT NULL
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS recurrences (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id    INTEGER NOT NULL REFERENCES events(id),
            rule        TEXT NOT NULL,
            starts_on   TEXT NOT NULL,
            ends_on     TEXT NOT NULL,
            admin_note  TEXT DEFAULT '',
            is_approved INTEGER DEFAULT 0,
            approved_by TEXT DEFAULT '',
            created_at  TEXT NOT NULL
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS categories (
            slug        TEXT PRIMARY KEY,
            name        TEXT NOT NULL,
            color       TEXT DEFAULT 'F4af',
            sort_order  INTEGER DEFAULT 0
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS admin_sessions (
            token       TEXT PRIMARY KEY,
            expires_at  TEXT NOT NULL
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS settings (
            key         TEXT PRIMARY KEY,
            value       TEXT NOT NULL
        )
    """)

    # Default categories
    defaults = [
        ("veranstaltung", "Event",  "4af", 1),
        ("treffen",       "Meeting",         "1a6", 2),
        ("markt",         "Market",           "ca4", 3),
        ("workshop",      "Workshop",        "a64", 4),
        ("online",        "Online Meeting",  "4be", 5),
        ("aktion",        "Action",          "f55", 6),
        ("diverses",      "Miscellaneous",        "777", 7),
    ]
    for slug, name, color, order in defaults:
        cur.execute(
            "INSERT OR IGNORE INTO categories (slug, name, color, sort_order) VALUES (?,?,?,?)",
            (slug, name, color, order)
        )

    # Migration: remove leading F from old color values
    rows = cur.execute("SELECT slug, color FROM categories").fetchall()
    for row in rows:
        if row[1].startswith("F") and len(row[1]) == 4:
            cur.execute("UPDATE categories SET color=? WHERE slug=?", (row[1][1:], row[0]))

    c.commit()
    c.close()

# ─── Date/Time helper functions ────────────────────────────────────
def now_iso():
    return datetime.utcnow().strftime("%Y-%m-%d %H:%M")

def parse_dt(s):
    """Parse date string, returns datetime or None.
    Supports DD-MM-YYYY (input) and YYYY-MM-DD (internal storage)."""
    if not s:
        return None
    for fmt in ("%d-%m-%Y %H:%M", "%d-%m-%Y",
                "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            return datetime.strptime(s.strip(), fmt)
        except ValueError:
            pass
    return None

def normalize_dt(s):
    """Convert user input DD-MM-YYYY → internal YYYY-MM-DD HH:MM."""
    dt = parse_dt(s)
    if not dt:
        return s
    if dt.hour or dt.minute:
        return dt.strftime("%Y-%m-%d %H:%M")
    return dt.strftime("%Y-%m-%d")

def fmt_field_dt(s):
    """Convert internal YYYY-MM-DD for prefilling fields DD-MM-YYYY."""
    if not s:
        return ""
    dt = parse_dt(s)
    if not dt:
        return s
    if dt.hour or dt.minute:
        return dt.strftime("%d-%m-%Y %H:%M")
    return dt.strftime("%d-%m-%Y")

def fmt_dt(s):
    """Format datetime string for display."""
    dt = parse_dt(s)
    if not dt:
        return s or "?"
    days = ["Mo","Tu","We","Th","Fr","Sa","Su"]
    wd = days[dt.weekday()]
    date_s = dt.strftime("%d-%m-%Y")
    if dt.hour == 0 and dt.minute == 0:
        return f"{wd}, {date_s}"
    return f"{wd}, {date_s} · {dt.strftime('%H:%M')}"

def fmt_date_short(s):
    """'Mon 14-04' for list row"""
    dt = parse_dt(s)
    if not dt:
        return s or "?"
    days = ["Mo","Tu","We","Th","Fr","Sa","Su"]
    wd = days[dt.weekday()]
    return f"{wd} {dt.strftime('%d-%m')}"

def month_name(m):
    names = ["","January","February","March","April","May","June",
             "July","August","September","October","November","December"]
    return names[int(m)]

# ─── Calendar period ──────────────────────────────────────────────
def calendar_months():
    """Returns list of (year, month) for the entire calendar period."""
    result = []
    y, m = CALENDAR_YEAR, 1
    while True:
        result.append((y, m))
        m += 1
        if m > 12:
            m = 1
            y += 1
        if y == CALENDAR_YEAR + 1 and m > EXTRA_MONTHS:
            break
    return result

def is_archive_dt(dt_str):
    """True if event is more than ARCHIVE_DAYS in the past."""
    dt = parse_dt(dt_str)
    if not dt:
        return False
    return dt.date() < (date.today() - timedelta(days=ARCHIVE_DAYS))

def is_past(dt_str):
    """True if event is in the past."""
    dt = parse_dt(dt_str)
    if not dt:
        return False
    return dt.date() < date.today()

# ─── Expand recurrences ───────────────────────────────────────────
def expand_recurrence(rec, base_event):
    """
    Returns list of virtual event dicts for a recurrence rule.
    Only future and archive-window events.
    """
    if not rec["is_approved"]:
        return []

    rule     = rec["rule"]         # weekly / biweekly / monthly
    start    = parse_dt(rec["starts_on"])
    end      = parse_dt(rec["ends_on"])
    if not start or not end:
        return []

    base_time = ""
    dt_base = parse_dt(base_event["start_dt"])
    if dt_base and (dt_base.hour or dt_base.minute):
        base_time = dt_base.strftime(" %H:%M")

    cutoff_past = date.today() - timedelta(days=ARCHIVE_DAYS)

    results = []
    cur = start.date()
    while cur <= end.date():
        if cur >= cutoff_past:
            dt_str = cur.strftime("%Y-%m-%d") + base_time
            results.append({
                "id":         base_event["id"],
                "title":      base_event["title"],
                "body":       base_event["body"],
                "category":   base_event["category"],
                "start_dt":   dt_str,
                "end_dt":     base_event["end_dt"],
                "location":   base_event["location"],
                "lxmf":       base_event["lxmf"],
                "contact":    base_event["contact"],
                "edit_token": base_event["edit_token"],
                "is_approved": 1,
                "recur_id":   rec["id"],
                "recur_rule": rule,
                "is_recur":   True,
            })
        # next event
        if rule == "weekly":
            cur += timedelta(weeks=1)
        elif rule == "biweekly":
            cur += timedelta(weeks=2)
        elif rule == "monthly":
            # same day next month
            m = cur.month + 1
            y = cur.year
            if m > 12:
                m = 1
                y += 1
            day = min(cur.day, monthrange(y, m)[1])
            cur = cur.replace(year=y, month=m, day=day)
        else:
            break
    return results

# ─── Load events ───────────────────────────────────────────────────
def get_events_for_month(year, month, include_pending=False):
    """
    All events (single + expanded recurrences) for a month.
    Sorted by start_dt.
    """
    c = get_db()
    first = f"{year:04d}-{month:02d}-01"
    _, last_day = monthrange(year, month)
    last  = f"{year:04d}-{month:02d}-{last_day:02d} 23:59"

    q = "SELECT * FROM events WHERE start_dt >= ? AND start_dt <= ?"
    params = [first, last]
    if not include_pending:
        q += " AND is_approved = 1"
    rows = c.execute(q, params).fetchall()

    events = [dict(r) for r in rows]
    for e in events:
        e["is_recur"] = False

    # Recurrences
    all_recur = c.execute(
        "SELECT * FROM recurrences WHERE is_approved = 1"
    ).fetchall()
    for rec in all_recur:
        base = c.execute(
            "SELECT * FROM events WHERE id = ?", (rec["event_id"],)
        ).fetchone()
        if not base:
            continue
        for ev in expand_recurrence(dict(rec), dict(base)):
            dt = parse_dt(ev["start_dt"])
            if dt and dt.year == year and dt.month == month:
                events.append(ev)

    c.close()
    events.sort(key=lambda e: e["start_dt"])
    return events

def get_event_by_id(event_id):
    c = get_db()
    row = c.execute("SELECT * FROM events WHERE id = ?", (event_id,)).fetchone()
    c.close()
    return dict(row) if row else None

def get_event_by_token(token):
    c = get_db()
    row = c.execute(
        "SELECT * FROM events WHERE edit_token = ?", (token,)
    ).fetchone()
    c.close()
    return dict(row) if row else None

def get_recurrence_for_event(event_id):
    c = get_db()
    row = c.execute(
        "SELECT * FROM recurrences WHERE event_id = ?", (event_id,)
    ).fetchone()
    c.close()
    return dict(row) if row else None

def get_pending_events():
    c = get_db()
    rows = c.execute(
        "SELECT * FROM events WHERE is_approved = 0 ORDER BY created_at"
    ).fetchall()
    c.close()
    return [dict(r) for r in rows]

def get_pending_recurrences():
    c = get_db()
    rows = c.execute("""
        SELECT r.*, e.title as event_title
        FROM recurrences r
        JOIN events e ON r.event_id = e.id
        WHERE r.is_approved = 0
        ORDER BY r.created_at
    """).fetchall()
    c.close()
    return [dict(r) for r in rows]

def get_all_upcoming_events():
    """All upcoming + today's approved events for admin overview."""
    c = get_db()
    today = date.today().strftime("%Y-%m-%d")
    rows = c.execute(
        "SELECT * FROM events WHERE start_dt >= ? AND is_approved = 1 ORDER BY start_dt",
        (today,)
    ).fetchall()
    c.close()
    return [dict(r) for r in rows]

def get_archive_events():
    """Events of the last ARCHIVE_DAYS days, descending."""
    c = get_db()
    cutoff = (date.today() - timedelta(days=ARCHIVE_DAYS)).strftime("%Y-%m-%d")
    today  = date.today().strftime("%Y-%m-%d")
    rows = c.execute(
        "SELECT * FROM events WHERE start_dt >= ? AND start_dt < ? AND is_approved = 1 ORDER BY start_dt DESC",
        (cutoff, today)
    ).fetchall()
    c.close()
    return [dict(r) for r in rows]

# ─── Write events ─────────────────────────────────────────────────
def create_event(title, body, category, start_dt, end_dt,
                 location, lxmf, contact):
    token = secrets.token_hex(16)
    c = get_db()
    cur = c.cursor()
    approved = 0 if require_approval() else 1
    cur.execute("""
        INSERT INTO events
        (title, body, category, start_dt, end_dt, location, lxmf, contact,
         edit_token, is_approved, created_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?)
    """, (title, body, category, start_dt, end_dt,
          location, lxmf, contact, token, approved, now_iso()))
    event_id = cur.lastrowid
    c.commit()
    c.close()
    return event_id, token

def create_recurrence(event_id, rule, starts_on, ends_on):
    c = get_db()
    c.execute("""
        INSERT INTO recurrences
        (event_id, rule, starts_on, ends_on, is_approved, created_at)
        VALUES (?,?,?,?,0,?)
    """, (event_id, rule, starts_on, ends_on, now_iso()))
    c.commit()
    c.close()

def update_event(event_id, title, body, category, start_dt,
                 end_dt, location, lxmf, contact):
    c = get_db()
    c.execute("""
        UPDATE events SET
        title=?, body=?, category=?, start_dt=?, end_dt=?,
        location=?, lxmf=?, contact=?
        WHERE id=?
    """, (title, body, category, start_dt, end_dt,
          location, lxmf, contact, event_id))
    c.commit()
    c.close()

def delete_event(event_id):
    c = get_db()
    c.execute("DELETE FROM recurrences WHERE event_id = ?", (event_id,))
    c.execute("DELETE FROM events WHERE id = ?", (event_id,))
    c.commit()
    c.close()

def approve_event(event_id):
    c = get_db()
    c.execute("UPDATE events SET is_approved=1 WHERE id=?", (event_id,))
    c.commit()
    c.close()

def approve_recurrence(recur_id, rule, starts_on, ends_on, admin_note=""):
    c = get_db()
    c.execute("""
        UPDATE recurrences SET
        is_approved=1, rule=?, starts_on=?, ends_on=?, admin_note=?
        WHERE id=?
    """, (rule, starts_on, ends_on, admin_note, recur_id))
    c.commit()
    c.close()

def delete_recurrence(recur_id):
    c = get_db()
    c.execute("DELETE FROM recurrences WHERE id=?", (recur_id,))
    c.commit()
    c.close()

# ─── Categories ───────────────────────────────────────────────────
def get_categories():
    c = get_db()
    rows = c.execute(
        "SELECT * FROM categories ORDER BY sort_order"
    ).fetchall()
    c.close()
    return [dict(r) for r in rows]

def get_category(slug):
    c = get_db()
    row = c.execute(
        "SELECT * FROM categories WHERE slug=?", (slug,)
    ).fetchone()
    c.close()
    return dict(row) if row else {"slug": slug, "name": slug, "color": "F777"}

def category_color(slug):
    cat = get_category(slug)
    return cat.get("color", "777")

# ─── Admin session ─────────────────────────────────────────────────
def check_admin_password(pw):
    c = get_db()
    row = c.execute(
        "SELECT value FROM settings WHERE key='admin_pw_hash'"
    ).fetchone()
    c.close()
    if not row:
        return False
    stored = row["value"]
    salt = stored[:32]
    expected = salt + hashlib.sha256((salt + pw).encode()).hexdigest()
    return stored == expected

def create_admin_session():
    token = secrets.token_hex(32)
    exp = (datetime.utcnow() + timedelta(seconds=SESSION_TTL)).strftime(
        "%Y-%m-%d %H:%M"
    )
    c = get_db()
    c.execute(
        "INSERT INTO admin_sessions (token, expires_at) VALUES (?,?)",
        (token, exp)
    )
    c.commit()
    c.close()
    return token

def check_admin_session(token):
    if not token:
        return False
    c = get_db()
    row = c.execute(
        "SELECT * FROM admin_sessions WHERE token=?", (token,)
    ).fetchone()
    c.close()
    if not row:
        return False
    exp = parse_dt(row["expires_at"])
    return exp and datetime.utcnow() < exp

def delete_admin_session(token):
    c = get_db()
    c.execute("DELETE FROM admin_sessions WHERE token=?", (token,))
    c.commit()
    c.close()

# ─── Cleanup ───────────────────────────────────────────────────────
def cleanup():
    """Delete expired admin sessions. Events remain (archive)."""
    now = now_iso()
    c = get_db()
    c.execute("DELETE FROM admin_sessions WHERE expires_at < ?", (now,))
    c.commit()
    c.close()

# ─── Settings ──────────────────────────────────────────────────────
def get_setting(key, default="0"):
    c = get_db()
    row = c.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
    c.close()
    return row["value"] if row else default

def set_setting(key, value):
    c = get_db()
    c.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?,?)", (key, value))
    c.commit()
    c.close()

def require_approval():
    """True if single events also require approval."""
    return get_setting("require_approval", "0") == "1"

# ─── Navigation ────────────────────────────────────────────────────
def nav_bar(is_admin=False, token=""):
    sess = f"|session={token}" if token else ""
    parts = [
        f"`[Calendar`{page_path}/index.mu`session={token}]",
        f"`[Help`{page_path}/help.mu`session={token}]",
        f"`[Add Event`{page_path}/new.mu`session={token}]",
        f"`[Archive`{page_path}/archive.mu`session={token}]",
    ]
    if is_admin:
        parts.append(f"`[`!Admin`!`{page_path}/admin/admin.mu`session={token}]")
    else:
        parts.append(f"`[Admin`{page_path}/admin/admin_login.mu]")
    parts.append(f"`Fca4`[← Node-Start`{node_homepage}]`f")
    return "  ".join(parts)

def print_header(subtitle=None):
    """Unified header: title + description."""
    print(f"`c`!`F0af{site_name}`!`f`c")
    print(f"`c`F777{site_description}`f`c")
    if subtitle:
        print(f"`c`F555{subtitle}`f`c")
    print("")

def print_footer():
    """Suite footer."""
    print("-")
    print("`c`F444Off-Grid Community Suite · NomadNet`f`c")

def lxmf_link(address):
    """Clickable LXMF address."""
    if address:
        return f"`[{address}`lxmf://{address}]"
    return ""

# Initialize on import
init_db()
cleanup()
