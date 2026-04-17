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
    event_id = int(os.environ.get("var_id", "0"))
except ValueError:
    event_id = 0

action    = os.environ.get("var_action", "")
submitted = (action == "save") or ("field_title" in os.environ)

print(f">{m.site_name} · Admin")
print(m.nav_bar(True, token))
print("-")

# ─── Delete ──────────────────────────────────────────────────────
if action == "delete" and event_id:
    m.delete_event(event_id)
    print(">>Event deleted")
    print("`F1a6Event deleted.`f")
    print(f"`[<- Admin`{m.page_path}/admin/admin.mu`session={token}]")
    sys.exit()

ev = m.get_event_by_id(event_id) if event_id else None
if not ev:
    print("`Ff55Event nicht gefunden.`f")
    print(f"`[<- Admin`{m.page_path}/admin/admin.mu`session={token}]")
    sys.exit()

notice = ""
if submitted:
    try:
        title    = os.environ.get("field_title", "").strip()[:60]
        body     = os.environ.get("field_body", "").strip()[:500]
        category = os.environ.get("field_category", ev["category"]).strip()
        start_dt = os.environ.get("field_start_dt", "").strip()
        end_dt   = os.environ.get("field_end_dt", "").strip()
        location = os.environ.get("field_location", "").strip()[:80]
        lxmf     = os.environ.get("field_lxmf", "").strip()
        contact  = os.environ.get("field_contact", "").strip()[:100]

        if not title or not start_dt or not m.parse_dt(start_dt):
            notice = "`Ff55Title and valid date are required.`f"
        else:
            if lxmf and not (len(lxmf) == 32 and
                             all(c in "0123456789abcdefABCDEF" for c in lxmf)):
                lxmf = ev["lxmf"]
            start_dt = m.normalize_dt(start_dt)
            end_dt   = m.normalize_dt(end_dt) if end_dt else ""
            m.update_event(event_id, title, body, category,
                           start_dt, end_dt, location, lxmf, contact)
            print(">>Gespeichert")
            print("`F1a6Changes saved.`f")
            print(f"`[Zum Event`{m.page_path}/event.mu`id={event_id}|session={token}]"
                  f"  `[<- Admin`{m.page_path}/admin/admin.mu`session={token}]")
            sys.exit()
    except Exception as e:
        notice = f"`Ff55Fehler: {e}`f"

# ─── Formular ─────────────────────────────────────────────────────
print(f">>Edit: {ev['title'][:40]}")

if notice:
    print()
    print(notice)

print()
cats = m.get_categories()
print("`!Category`!")
for cat in cats:
    print(f"`<^|category|{cat['slug']}`>  ", end="")
    print(f"`F{cat['color']} {cat['name']}`f")

print()
print("`!Title`!")
print(f"`B333`<40|title`{ev['title']}`>`b")

print()
print("`!Date (DD-MM-YYYY HH:MM)`!")
disp_start = m.fmt_field_dt(ev['start_dt'])
print(f"`B333`<20|start_dt`{disp_start}`>`b")

print()
print("`!Ende (optional)`!")
disp_end   = m.fmt_field_dt(ev.get('end_dt',''))
print(f"`B333`<20|end_dt`{disp_end}`>`b")

print()
print("`!Ort`!")
print(f"`B333`<40|location`{ev.get('location','')}`>`b")

print()
print("`!Description`!")
print(f"`B333`<55|body`{ev.get('body','')}`>`b")

print()
print("`!LXMF`!")
print(f"`B333`<32|lxmf`{ev.get('lxmf','')}`>`b")

print()
print("`!Contact`!")
print(f"`B333`<40|contact`{ev.get('contact','')}`>`b")

print()
m.print_footer()
