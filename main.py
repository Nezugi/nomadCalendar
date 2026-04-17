#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")

from datetime import date

today     = date.today()
cur_year  = today.year
cur_month = today.month

token    = os.environ.get("var_session", "")
is_admin = m.check_admin_session(token)

m.print_header()
print(m.nav_bar(is_admin, token))
print("-")

all_months = m.calendar_months()

for (year, month) in all_months:
    is_current = (year == cur_year and month == cur_month)
    is_next    = (year == cur_year and month == cur_month + 1) or \
                 (cur_month == 12 and year == cur_year + 1 and month == 1)

    month_label = f"{m.month_name(month)} {year}"

    if is_current or is_next:
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

    else:
        events  = m.get_events_for_month(year, month)
        count   = len(events)
        count_s = f"`F555({count})`f" if count else ""
        print(f"`[+ {month_label}`{m.page_path}/month.mu`y={year}|m={month}|session={token}]", end="")
        print(count_s)

m.print_footer()
