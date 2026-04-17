#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")

from datetime import date

token    = os.environ.get("var_session", "")
is_admin = m.check_admin_session(token)

try:
    year  = int(os.environ.get("var_y", date.today().year))
    month = int(os.environ.get("var_m", date.today().month))
except ValueError:
    year  = date.today().year
    month = date.today().month

month_label = f"{m.month_name(month)} {year}"

m.print_header()
print(m.nav_bar(is_admin, token))
print("-")
print(f">>`!{month_label}`!")

events = m.get_events_for_month(year, month)

if not events:
    print("`F555No events this month.`f")
else:
    for ev in events:
        cat      = m.get_category(ev["category"])
        color    = cat["color"]
        date_s   = m.fmt_date_short(ev["start_dt"])
        dt       = m.parse_dt(ev["start_dt"])
        time_s   = dt.strftime("%H:%M") if dt and (dt.hour or dt.minute) else "    "
        title    = ev["title"][:45]
        cat_name = cat["name"][:12]
        eid      = ev["id"]
        recur_mark = "`F4be↻`f " if ev.get("is_recur") else ""

        print(f"`F777 {date_s}  `f", end="")
        if time_s.strip():
            print(f"`! {time_s}  `!", end="")
        print(f"`[{title}`{m.page_path}/event.mu`id={eid}|session={token}]", end="")
        if recur_mark:
            print("`F4be ↻`f", end="")
        print(f"`F{color} {cat_name}`f")

print()
m.print_footer()
