#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
import main as m

print("#!c=0")

token = os.environ.get("var_session", "")
if not m.check_admin_session(token):
    m.print_header()
    print("`Ff55Nicht eingeloggt.`f")
    print(f"`[-> Login`{m.page_path}/admin/admin_login.mu]")
    sys.exit()

try:
    rid = int(os.environ.get("var_rid", "0"))
except ValueError:
    rid = 0

action    = os.environ.get("var_action", "")
submitted = (action == "save") or ("field_rule" in os.environ)

print(f">{m.site_name} · Admin")
print(m.nav_bar(True, token))
print("-")

if not rid:
    print("`Ff55Keine Recurrences-ID angegeben.`f")
    print(f"`[<- Admin`{m.page_path}/admin/admin.mu`session={token}]")
    sys.exit()

db = m.get_db()
rec_row = db.execute("SELECT r.*, e.title as event_title FROM recurrences r JOIN events e ON r.event_id=e.id WHERE r.id=?", (rid,)).fetchone()
db.close()

if not rec_row:
    print("`Ff55Recurrence nicht gefunden.`f")
    print(f"`[<- Admin`{m.page_path}/admin/admin.mu`session={token}]")
    sys.exit()

rec = dict(rec_row)

# ─── Save / Approve ─────────────────────────────────────
notice = ""
if submitted:
    try:
        rule     = os.environ.get("field_rule", rec["rule"]).strip()
        starts   = os.environ.get("field_starts_on", rec["starts_on"]).strip()
        ends     = os.environ.get("field_ends_on", rec["ends_on"]).strip()
        note     = os.environ.get("field_admin_note", "").strip()[:100]

        if rule not in ("weekly", "biweekly", "monthly"):
            notice = "`Ff55Invalid recurrence rule.`f"
        elif not m.parse_dt(starts) or not m.parse_dt(ends):
            notice = "`Ff55Invalid date.`f"
        else:
            starts = m.normalize_dt(starts)
            ends   = m.normalize_dt(ends)
            m.approve_recurrence(rid, rule, starts, ends, note)
            print(">>Recurrence freigeschaltet")
            print("`F1a6Recurrence wurde freigeschaltet.`f")
            print()
            print(f"`[<- Admin`{m.page_path}/admin/admin.mu`session={token}]")
            sys.exit()
    except Exception as e:
        notice = f"`Ff55Fehler: {e}`f"

# ─── Formular ─────────────────────────────────────────────────────
print(f">>Recurrence for: `!{rec['event_title'][:40]}`!")
print()
print(f"`F555Eingereicht: {rec['created_at'][:10]}`f")
print(f"`F555Original rule: {rec['rule']}  ab {rec['starts_on'][:10]}  bis {rec['ends_on'][:10]}`f")

if notice:
    print()
    print(notice)

print()
print("`!Regel anpassen`!")
print("`<^|rule|weekly`>  Weekly")
print("`<^|rule|biweekly`>  Biweekly")
print("`<^|rule|monthly`>  Monthly")

print()
print("`!First occurrence (YYYY-MM-DD)`!")
disp_starts = m.fmt_field_dt(rec['starts_on'])
print(f"`B333`<20|starts_on`{disp_starts}`>`b")

print()
print("`!Last occurrence (YYYY-MM-DD)`!")
disp_ends = m.fmt_field_dt(rec['ends_on'])
print(f"`B333`<20|ends_on`{disp_ends}`>`b")

print()
print("`!Admin-Notiz (optional, wird auf Detailseite angezeigt)`!")
print(f"`B333`<40|admin_note`{rec.get('admin_note','')}`>`b")

print()
m.print_footer()
