#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")

token    = os.environ.get("var_session", "")
is_admin = m.check_admin_session(token)

try:
    event_id = int(os.environ.get("var_id", "0"))
except ValueError:
    event_id = 0

ev = m.get_event_by_id(event_id) if event_id else None

m.print_header()
print(m.nav_bar(is_admin, token))
print("-")

if not ev:
    print("`Ff55Event nicht gefunden.`f")
    print(f"`[<- Back`{m.page_path}/index.mu]")
    sys.exit()

cat     = m.get_category(ev["category"])
color   = cat["color"]
is_past = m.is_past(ev["start_dt"])

print(f">>`!{ev['title']}`!")

if is_past:
    print("`F555(vergangener Event)`f")

print()

# Metadaten
print(f"`F777Wann:`f   `!{m.fmt_dt(ev['start_dt'])}`!")
if ev.get("end_dt"):
    print(f"`F777Bis:`f    {m.fmt_dt(ev['end_dt'])}")
print(f"`F777Wo:`f    {ev['location'] or '(kein Ort angegeben)'}")
print(f"`F777Typ:`f   `F{color} {cat['name']}`f")

# Recurrence
recur = m.get_recurrence_for_event(event_id)
if recur and recur["is_approved"]:
    rules = {"weekly": "weekly", "biweekly": "zweiweekly", "monthly": "monthly"}
    rule_s = rules.get(recur["rule"], recur["rule"])
    ends_disp = m.fmt_field_dt(recur["ends_on"])
    print(f"`F4be↻`f  Wiederholend: `!{rule_s}`!  bis {ends_disp}")
    if recur.get("admin_note"):
        print(f"`F555Hinweis: {recur['admin_note']}`f")

print()

# Description
if ev.get("body"):
    print(">>Description")
    for line in ev["body"].split("\n"):
        print(line)
    print()

# Contact
has_contact = ev.get("lxmf") or ev.get("contact")
if has_contact:
    print(">>Contact")
    if ev.get("lxmf"):
        print("`F4beLXMF:`f")
        print(f"{ev['lxmf']}")
    if ev.get("contact"):
        print(ev["contact"])
    print()

m.print_footer()
