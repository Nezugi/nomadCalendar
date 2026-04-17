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

action = os.environ.get("var_action", "")
notice = ""

if action:
    try:
        if action == "approve_event":
            eid = int(os.environ.get("var_eid", "0"))
            m.approve_event(eid)
            notice = "`F1a6Event freigeschaltet.`f"

        elif action == "delete_event":
            eid = int(os.environ.get("var_eid", "0"))
            m.delete_event(eid)
            notice = "`F555Event deleted.`f"

        elif action == "delete_recur":
            rid = int(os.environ.get("var_rid", "0"))
            m.delete_recurrence(rid)
            notice = "`F555Recurrence abgelehnt.`f"

        elif action == "set_approval":
            val = os.environ.get("var_val", "0")
            m.set_setting("require_approval", val)
            state = "aktiviert" if val == "1" else "deaktiviert"
            notice = f"`F1a6Freigabe-Pflicht {state}.`f"

        elif action == "logout":
            m.delete_admin_session(token)
            m.print_header()
            print("`F777Abgemeldet.`f")
            print(f"`[-> Home`{m.page_path}/index.mu]")
            sys.exit()

    except Exception as e:
        notice = f"`Ff55Fehler: {e}`f"

print(f">{m.site_name} · Admin")
print(m.nav_bar(True, token))
print("-")

if notice:
    print(notice)
    print()

# ── Freigabe-Einstellung ──────────────────────────────────────────
req = m.require_approval()
print(">>Settings")
if req:
    print("`Fca4Freigabe-Pflicht aktiv`f")
    print("`F555All new events (including single ones) require approvalen.`f")
    print(f"`[Freigabe-Pflicht deaktivieren`{m.page_path}/admin/admin.mu`action=set_approval|val=0|session={token}]")
else:
    print("`F1a6Freie Entryung aktiv`f")
    print("`F555Einmalige Events sind sofort sichtbar.`f")
    print(f"`[Freigabe-Pflicht aktivieren`{m.page_path}/admin/admin.mu`action=set_approval|val=1|session={token}]")

print()
print(f"`[Categoryn`{m.page_path}/admin/admin_cats.mu`session={token}]"
      f"  `[Logout`{m.page_path}/admin/admin.mu`action=logout|session={token}]")

print("-")

# ── Pending Events ───────────────────────────────────────────
pending = m.get_pending_events()
print(">>Pending Events")
print(f"`F555({len(pending)} ausstehend)`f")

if not pending:
    print("`F555Keine ausstehenden Events.`f")
else:
    for ev in pending:
        cat    = m.get_category(ev["category"])
        color  = cat["color"]
        date_s = m.fmt_date_short(ev["start_dt"])
        title  = ev["title"][:38]
        eid    = ev["id"]

        print(f"`F{color} {date_s}`f", end="")
        print(f"  `!{title}`!")
        print(f"`F555{cat['name']}`f")
        print(f"`[Approve`{m.page_path}/admin/admin.mu`action=approve_event|eid={eid}|session={token}]"
              f"  `[Edit`{m.page_path}/admin/admin_event.mu`id={eid}|session={token}]"
              f"  `[Delete`{m.page_path}/admin/admin.mu`action=delete_event|eid={eid}|session={token}]")
        print()

print("-")

# ── Pending Recurrences ────────────────────────────────────
pending_r = m.get_pending_recurrences()
print(">>Pending Recurrences")
print(f"`F555({len(pending_r)} ausstehend)`f")

if not pending_r:
    print("`F555Keine ausstehenden Recurrenceen.`f")
else:
    rules_label = {"weekly": "weekly", "biweekly": "zweiweekly", "monthly": "monthly"}
    for rec in pending_r:
        rid    = rec["id"]
        title  = rec.get("event_title", "?")[:38]
        starts = m.fmt_field_dt(rec["starts_on"])
        ends   = m.fmt_field_dt(rec["ends_on"])
        rule_s = rules_label.get(rec["rule"], rec["rule"])

        print(f"`!{title}`!")
        print(f"`F4be{rule_s}`f  ab {starts} bis {ends}")
        print(f"`[Approve`{m.page_path}/admin/admin_recur.mu`rid={rid}|session={token}]"
              f"  `[Reject`{m.page_path}/admin/admin.mu`action=delete_recur|rid={rid}|session={token}]")
        print()

m.print_footer()
