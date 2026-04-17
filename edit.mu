#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")

from datetime import date

token    = os.environ.get("var_session", "")
is_admin = m.check_admin_session(token)

m.print_header()
print(m.nav_bar(is_admin, token))
print("-")
print(">>Archive — letzte 3 Monate")
print()

events = m.get_archive_events()

if not events:
    print("`F555Keine archivierten Events.`f")
else:
    cur_month_key = None
    for ev in events:
        dt = m.parse_dt(ev["start_dt"])
        if not dt:
            continue
        month_key = f"{dt.year}-{dt.month:02d}"
        if month_key != cur_month_key:
            cur_month_key = month_key
            print(f"`!{m.month_name(dt.month)} {dt.year}`!")
            print("-")

        cat     = m.get_category(ev["category"])
        color   = cat["color"]
        date_s  = m.fmt_date_short(ev["start_dt"])
        time_s  = dt.strftime("%H:%M") if (dt.hour or dt.minute) else "    "
        title   = ev["title"][:45]
        eid     = ev["id"]

        print(f"`F555{date_s}`f  `F{color} {time_s}`f  "
              f"`[{title}`{m.page_path}/event.mu`id={eid}|session={token}]"
              f"`F555{cat['name']}`f")

print()
m.print_footer()
