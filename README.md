# nomadCalendar

A shared community event calendar for [NomadNet](https://github.com/markqvist/NomadNet) nodes — anyone can submit events, recurring events require admin approval, past events stay visible for 90 days.

Part of the [**Off-Grid Community Suite**](https://github.com/Nezugi/Off-Grid-Community-Suite/tree/main) for NomadNet nodes.

---

## Features

- **No account required** to submit an event
- **List view** — current and next month expanded by default; future months expand on click
- **Recurring events** — weekly, biweekly, or monthly; require admin approval
- **Single events** — visible immediately by default (configurable)
- **Edit token** — owners can edit or delete their event
- **Approval mode** — optional: require admin approval for all events
- **Archive** — past events visible for 90 days, read-only
- **Clickable LXMF addresses** — contact event organisers directly
- **Admin panel** — approve/reject events, manage categories, edit all events
- **No external packages** — only Python standard library

---

## Installation

```bash
# Installation of nomadCalendar

## 1. Clone the repository
git clone https://github.com/Nezugi/nomadCalendar
cd nomadCalendar

## 2. Copy calendar page into your NomadNet pages directory
cp -r calendar/ ~/.nomadnetwork/storage/pages/calendar/

## 3. Make all .mu files executable
chmod +x ~/.nomadnetwork/storage/pages/calendar/*.mu
chmod +x ~/.nomadnetwork/storage/pages/calendar/admin_*.mu

## 4. Edit main.py
nano ~/.nomadnetwork/storage/pages/calendar/main.py

# Adjust the following line to match your username:
# storage_path = "/home/YOUR_USER/.nomadCalendar"

## 5. Create the admin account
python3 ~/.nomadnetwork/storage/pages/calendar/setup_admin.py

# After installation, access the calendar via:
# YOUR_NODE_HASH:/page/calendar/index.mu

```

---

## Configuration

```python
storage_path     = "/home/YOUR_USER/.nomadCalendar"
page_path        = ":/page/calendar"
site_name        = "nomadCalendar"
site_description = "Community calendar for events & meetups"
node_homepage    = ":/page/index.mu"

CALENDAR_YEAR = 2026   # events run through EXTRA_MONTHS of the next year
EXTRA_MONTHS  = 3      # months into the next year to show
ARCHIVE_DAYS  = 90     # days past events remain visible
```

---

## File Structure

```
calendar/
├── main.py            ← database, sessions, helpers
├── setup_admin.py     ← CLI: set admin password
├── index.mu           ← start page: month list
├── month.mu           ← expanded month view
├── event.mu           ← event detail
├── new.mu             ← submit an event
├── edit_ask.mu        ← enter edit token
├── edit.mu            ← edit event (token-protected)
├── archive.mu         ← past events (read-only)
├── help.mu            ← user guide
└── admin/
    ├── admin_login.mu
    ├── admin.mu       ← pending events & recurrences
    ├── admin_event.mu ← edit / delete any event
    ├── admin_recur.mu ← approve recurring events
    └── admin_cats.mu  ← manage categories
```

---

## Recurring Events

1. Submit an event marked as recurring (weekly / biweekly / monthly)
2. The recurrence enters a **pending queue**
3. Admin reviews, adjusts start/end dates if needed, and approves
4. Approved recurrences expand automatically through the calendar year
5. No instances carry over to the next year — renew annually

---

## Approval Modes

| Mode | Single events | Recurring events |
|---|---|---|
| Default | Visible immediately | Require admin approval |
| Approval required (admin setting) | Require admin approval | Require admin approval |

---

## Permissions

| Action | Visitor | Owner (token) | Admin |
|---|---|---|---|
| Read events | ✓ | ✓ | ✓ |
| Submit event | ✓ | ✓ | ✓ |
| Edit own event | — | ✓ | ✓ |
| Delete own event | — | ✓ | ✓ |
| Approve recurring events | — | — | ✓ |
| Edit / delete any event | — | — | ✓ |
| Manage categories | — | — | ✓ |
| Toggle approval mode | — | — | ✓ |

---

## Database

SQLite at `~/.nomadCalendar/calendar.db` — created automatically. Date format throughout: `DD-MM-YYYY`.

---

## Access

```
YOUR_NODE_HASH:/page/calendar/index.mu
```

## License

MIT
