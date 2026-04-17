#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")

token     = os.environ.get("var_session", "")
is_admin  = m.check_admin_session(token)
etoken    = os.environ.get("var_etoken", "").strip()
action    = os.environ.get("var_action", "")
submitted = (action == "save") or ("field_title" in os.environ)
deleted   = (action == "delete")

m.print_header()
print(m.nav_bar(is_admin, token))
print("-")

# Token prüfen
if not etoken:
    print("`Ff55Kein Edit-Token angegeben.`f")
    print(f"`[<- Back`{m.page_path}/index.mu]")
    sys.exit()

ev = m.get_event_by_token(etoken)
if not ev:
    print("`Ff55Invalid edit token.`f")
    print(f"`[<- Back`{m.page_path}/index.mu]")
    sys.exit()

if m.is_archive_dt(ev["start_dt"]):
    print("`F555Archived event — editing not possible.`f")
    print(f"`[Zum Event`{m.page_path}/event.mu`id={ev['id']}]")
    sys.exit()

# ─── Delete ──────────────────────────────────────────────────────
if deleted:
    m.delete_event(ev["id"])
    print(">>Event deleted")
    print("`F1a6Event deleted.`f")
    print(f"`[<- Back`{m.page_path}/index.mu]")
    sys.exit()

# ─── Save ────────────────────────────────────────────────────
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

        if not title:
            notice = "`Ff55Title ist Pflichtfeld.`f"
        elif not start_dt or not m.parse_dt(start_dt):
            notice = "`Ff55Invalid date.`f"
        else:
            if lxmf and not (len(lxmf) == 32 and
                             all(c in "0123456789abcdefABCDEF" for c in lxmf)):
                lxmf = ev["lxmf"]

            start_dt = m.normalize_dt(start_dt)
            end_dt   = m.normalize_dt(end_dt) if end_dt else ""
            m.update_event(ev["id"], title, body, category,
                           start_dt, end_dt, location, lxmf, contact)
            print(">>Event updated")
            print("`F1a6Changes saved.`f")
            print()
            print(f"`[Zum Event`{m.page_path}/event.mu`id={ev['id']}|session={token}]"
                  f"  `[Back`{m.page_path}/index.mu`session={token}]")
            sys.exit()

    except Exception as e:
        notice = f"`Ff55Fehler: {e}`f"

# ─── Bearbeitungsformular ─────────────────────────────────────────
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
disp_start = m.fmt_field_dt(ev['start_dt'])
disp_end   = m.fmt_field_dt(ev.get('end_dt',''))
print("`!Date (DD-MM-YYYY oder DD-MM-YYYY HH:MM)`!")
print(f"`B333`<20|start_dt`{disp_start}`>`b")

print()
print("`!Ende (optional)`!")
print(f"`B333`<20|end_dt`{disp_end}`>`b")

print()
print("`!Ort`!")
print(f"`B333`<40|location`{ev.get('location','')}`>`b")

print()
print("`!Description`!")
print(f"`B333`<55|body`{ev.get('body','')}`>`b")

print()
print("`!LXMF address`!")
print(f"`B333`<32|lxmf`{ev.get('lxmf','')}`>`b")

print()
print("`!Contact`!")
print(f"`B333`<40|contact`{ev.get('contact','')}`>`b")

print()
m.print_footer()
