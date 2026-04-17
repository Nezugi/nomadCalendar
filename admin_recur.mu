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

action    = os.environ.get("var_action", "")
submitted = (action == "add") or ("field_slug" in os.environ)
notice    = ""

if submitted:
    try:
        slug  = os.environ.get("field_slug", "").strip().lower()[:20]
        name  = os.environ.get("field_name", "").strip()[:30]
        color = os.environ.get("field_color", "F777").strip()[:4]

        if not slug or not name:
            notice = "`Ff55Slug und Name sind Pflicht.`f"
        elif not slug.replace("-","").replace("_","").isalnum():
            notice = "`Ff55Slug darf nur Buchstaben, Zahlen, - und _ enthalten.`f"
        else:
            c = m.get_db()
            existing = c.execute("SELECT slug FROM categories WHERE slug=?", (slug,)).fetchone()
            if existing:
                notice = "`Ff55Slug existiert bereits.`f"
            else:
                max_ord = c.execute("SELECT MAX(sort_order) FROM categories").fetchone()[0] or 0
                c.execute(
                    "INSERT INTO categories (slug, name, color, sort_order) VALUES (?,?,?,?)",
                    (slug, name, color, max_ord + 1)
                )
                c.commit()
                notice = f"`F1a6Category '{name}' angelegt.`f"
            c.close()
    except Exception as e:
        notice = f"`Ff55Fehler: {e}`f"

elif action == "delete":
    slug_del = os.environ.get("var_slug", "")
    if slug_del:
        try:
            c = m.get_db()
            used = c.execute("SELECT COUNT(*) FROM events WHERE category=?", (slug_del,)).fetchone()[0]
            if used > 0:
                notice = f"`Ff55Category hat noch {used} Events — erst Events umziehen.`f"
            else:
                c.execute("DELETE FROM categories WHERE slug=?", (slug_del,))
                c.commit()
                notice = "`F555Category deleted.`f"
            c.close()
        except Exception as e:
            notice = f"`Ff55Fehler: {e}`f"

# ─── Ausgabe ──────────────────────────────────────────────────────
print(f">{m.site_name} · Admin")
print(m.nav_bar(True, token))
print("-")
print(">>Categoryn")

if notice:
    print()
    print(notice)

print()
cats = m.get_categories()
for cat in cats:
    c2 = m.get_db()
    count = c2.execute("SELECT COUNT(*) FROM events WHERE category=?", (cat["slug"],)).fetchone()[0]
    c2.close()
    print(f"`F{cat['color']} `!{cat['name']}`!`f")
print(f"`F555  slug: {cat['slug']}  ({count} Events)`f  "
          f"`[Delete`{m.page_path}/admin/admin_cats.mu`action=delete|slug={cat['slug']}|session={token}]")

print()
m.print_footer()
