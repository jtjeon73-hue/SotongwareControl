# Verify deployed hosting bundle contains admin dart-defines. No secret printing.
from pathlib import Path
import re
import urllib.request
import sys

local = Path("tool/deploy_control.local.ps1").read_text(encoding="utf-8")
em = re.search(r'AdminEmail\s*=\s*"([^"]+)"', local)
uid = re.search(r'AdminUid\s*=\s*"([^"]+)"', local)
if not em or not uid:
    print("local_missing")
    sys.exit(1)

js = urllib.request.urlopen(
    "https://sotongware-control.web.app/main.dart.js", timeout=90
).read().decode("utf-8", "ignore")

print("live_admin_email_configured", em.group(1) in js)
print("live_admin_uid_configured", uid.group(1) in js)
print(
    "old_config_error_phrase_absent",
    "관리자 인증 설정이 완료되지 않았습니다" not in js,
)
print(
    "new_config_fallback_message_present",
    "관리자 인증 설정을 확인할 수 없습니다" in js,
)
print("public_services_label_present", "공개 서비스" in js)

ok = em.group(1) in js and uid.group(1) in js
sys.exit(0 if ok else 2)
