#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")

from datetime import date

token    = os.environ.get("var_session", "")
is_admin = m.check_admin_session(token)

# ─── Submit-Erkennung ─────────────────────────────────────────────
action = os.environ.get("var_action", "")
submitted = (action == "submit") or ("field_title" in os.environ)

notice  = ""
success = False
new_token = ""
new_id    = 0

if submitted:
    try:
        title    = os.environ.get("field_title", "").strip()[:60]
        body     = os.environ.get("field_body", "").strip()[:500]
        category = os.environ.get("field_category", "diverses").strip()
        start_dt = os.environ.get("field_start_dt", "").strip()
        end_dt   = os.environ.get("field_end_dt", "").strip()
        location = os.environ.get("field_location", "").strip()[:80]
        lxmf     = os.environ.get("field_lxmf", "").strip()
        contact  = os.environ.get("field_contact", "").strip()[:100]

        # Recurrence
        recur_rule   = os.environ.get("field_recur_rule", "").strip()
        recur_ends   = os.environ.get("field_recur_ends", "").strip()

        # Validierung
        if not title:
            notice = "`Ff55Title is required.`f"
        elif not start_dt:
            notice = "`Ff55Date is required.`f"
        elif not m.parse_dt(start_dt):
            notice = "`Ff55Invalid date. Format: DD-MM-YYYY or DD-MM-YYYY HH:MM`f"
        elif not lxmf and not contact:
            notice = "`Ff55Please provide at least LXMF address or contact info.`f"
        else:
            # LXMF validieren
            if lxmf and not (len(lxmf) == 32 and
                             all(c in "0123456789abcdefABCDEF" for c in lxmf)):
                lxmf = ""

            start_dt   = m.normalize_dt(start_dt)
            end_dt     = m.normalize_dt(end_dt) if end_dt else ""
            recur_ends = m.normalize_dt(recur_ends) if recur_ends else ""

            new_id, new_token = m.create_event(
                title, body, category, start_dt, end_dt,
                location, lxmf, contact
            )

            # Recurrence anlegen?
            if recur_rule in ("weekly", "biweekly", "monthly") and recur_ends:
                if m.parse_dt(recur_ends):
                    m.create_recurrence(new_id, recur_rule, start_dt, recur_ends)

            success = True

    except Exception as e:
        notice = f"`Ff55Error: {e}`f"

# ─── Ausgabe ──────────────────────────────────────────────────────
m.print_header()
print(m.nav_bar(is_admin, token))
print("-")
print(">>Add Event")

if success:
    cat = m.get_category(os.environ.get("field_category", "diverses"))
    print()
    print("`F1a6Event submitted!`f")
    print()
    print(f"`!Your edit token (save this!):`!")
    print()
    print(f"`F4be{new_token}`f")
    print()
    print("`F555Use this token to edit your event later.`f")
    print("`F555The token is only shown once.`f")

    # Recurrence eingereicht?
    recur_rule = os.environ.get("field_recur_rule", "")
    if recur_rule in ("weekly", "biweekly", "monthly"):
        print()
        print("`Fca4The recurrence rule has been submitted and will be reviewed by an admin.`f")

    print()
    print("-")
    print(f"`[View Event`{m.page_path}/event.mu`id={new_id}|session={token}]"
          f"  `[Add another`{m.page_path}/new.mu]"
          f"  `[Back`{m.page_path}/index.mu]")
    sys.exit()

# ─── Formular ─────────────────────────────────────────────────────
if notice:
    print()
    print(notice)

print()

# Categoryn als Radio-Buttons
cats = m.get_categories()
print("`!Category`!")
for cat in cats:
    print(f"`<^|category|{cat['slug']}`>  ", end="")
    print(f"`F{cat['color']} {cat['name']}`f")

print()
print("`!Title`!")
print("`F555(Required, max. 60 chars)`f")
print("`B333`<40|title`>`b")

print()
print("`!Date & Time`!")
print("`F555(Required: DD-MM-YYYY or DD-MM-YYYY HH:MM)`f")
print("`B333`<20|start_dt`>`b")

print()
print("`!End (optional)`!")
print("`F555(DD-MM-YYYY HH:MM)`f")
print("`B333`<20|end_dt`>`b")

print()
print("`!Location`!")
print("`F555(optional)`f")
print("`B333`<40|location`>`b")

print()
print("`!Description`!")
print("`F555(optional, max. 500 chars)`f")
print("`B333`<55|body`>`b")

print()
print("`!LXMF address`!")
print("`F555(optional, 32 hex chars)`f")
print("`B333`<32|lxmf`>`b")

print()
print("`!Contact / Additional Info`!")
print("`Ff55(Required – at least LXMF or contact)`f")
print("`B333`<40|contact`>`b")

print()
print("-")
print("`!Recurrence`!")
print("`F555(optional — reviewed by admin)`f")
print()
print("`<^|recur_rule|`>")
print("`F555No recurrence`f")
print("`<^|recur_rule|weekly`>  Weekly")
print("`<^|recur_rule|biweekly`>  Biweekly")
print("`<^|recur_rule|monthly`>  Monthly")
print()
print("`F555Last occurrence (DD-MM-YYYY):`f")
print("`B333`<20|recur_ends`>`b")

print()
m.print_footer()
