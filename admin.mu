#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
import main as m

print("#!c=0")

action    = os.environ.get("var_action", "")
submitted = (action == "login") or ("field_password" in os.environ)
notice    = ""

if submitted:
    try:
        pw = os.environ.get("field_password", "")
        if m.check_admin_password(pw):
            token = m.create_admin_session()
            m.print_header()
            print("-")
            print(">>Admin Login")
            print()
            print("`F1a6Login successful.`f")
            print()
            print(f"`[-> Admin Panel`{m.page_path}/admin/admin.mu`session={token}]")
            sys.exit()
        else:
            notice = "`Ff55Wrong password.`f"
    except Exception as e:
        notice = f"`Ff55Error: {e}`f"

m.print_header("Admin Login")
print(m.nav_bar(False, ""))
print()
print(">>Admin Login")
print()
if notice:
    print(notice)
    print()
print("`FbbbPassword:`f")
print("`B333`<!32|password`>`b")
print()
print(f"`[Login`{m.page_path}/admin/admin_login.mu`*|action=login]")
print()
print(f"`[<- Back`{m.page_path}/index.mu]")
m.print_footer()
