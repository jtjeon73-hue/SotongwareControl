# Verify deployed hosting bundle contains admin dart-defines. No secret printing.
from pathlib import Path
import hashlib
import re
import urllib.request
import sys
import time

local = Path("tool/deploy_control.local.ps1").read_text(encoding="utf-8")
em = re.search(r'AdminEmail\s*=\s*"([^"]+)"', local)
uid = re.search(r'AdminUid\s*=\s*"([^"]+)"', local)
if not em or not uid:
    print("local_missing")
    sys.exit(1)

js = urllib.request.urlopen(
    f"https://sotongware-control.web.app/main.dart.js?v={int(time.time())}",
    timeout=90,
).read()
local_js = Path("build/web/main.dart.js").read_bytes()
text = js.decode("utf-8", "ignore")

email_ok = em.group(1) in text
uid_ok = uid.group(1) in text
bundle_match = hashlib.sha256(js).digest() == hashlib.sha256(local_js).digest()
business_urls = (
    "https://sotong-automation-promo.web.app",
    "https://sotongware-apps-promo.web.app",
    "https://sotongware-ebook-promo.web.app",
    "https://sotongware-contents-promo.web.app",
    "https://sotongware-marketing.web.app",
)
business_urls_ok = all(url in text for url in business_urls)

print("live_admin_email_configured", email_ok)
print("live_admin_uid_configured", uid_ok)
print("live_bundle_matches_local_build", bundle_match)
print("five_business_urls_present", business_urls_ok)

ok = email_ok and uid_ok and bundle_match and business_urls_ok
sys.exit(0 if ok else 2)
