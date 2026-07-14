# Verifies dart-define values were baked into web build. Does not print secrets.
from pathlib import Path
import re
import sys

local = Path("tool/deploy_control.local.ps1").read_text(encoding="utf-8")
em = re.search(r'AdminEmail\s*=\s*"([^"]+)"', local)
uid = re.search(r'AdminUid\s*=\s*"([^"]+)"', local)
if not em or not uid:
    print("local_admin_config_missing")
    sys.exit(1)
email = em.group(1)
admin_uid = uid.group(1)

html = Path("build/web/index.html").read_text(encoding="utf-8")
js = Path("build/web/main.dart.js").read_text(encoding="utf-8", errors="ignore")

base_ok = 'base href="/"' in html or "base href='/'" in html
email_ok = email in js and len(email.strip()) > 0
uid_ok = admin_uid in js and len(admin_uid.strip()) > 0

print("base_href_ok", base_ok)
print("admin_email_configured", email_ok)
print("admin_uid_configured", uid_ok)

if not (base_ok and email_ok and uid_ok):
    sys.exit(2)
