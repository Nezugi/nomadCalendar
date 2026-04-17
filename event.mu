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

action    = os.environ.get("var_action", "")
submitted = (action == "check") or ("field_edit_token" in os.environ)

m.print_header()
print(m.nav_bar(is_admin, token))
m.print_footer()
