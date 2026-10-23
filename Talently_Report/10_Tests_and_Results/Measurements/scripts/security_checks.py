"""Security checks for Table 5.5: requests that the SAP service must refuse.
Each write re-sends the values already stored on an application, so even an accepted request would change nothing."""
import json
import sys

import b1_response_times as b

try:
    b.CSRF = b.fetch_csrf()
except b.SessionExpired as e:
    sys.exit(str(e))

apps = b.s.get(f"{b.RECRUIT}/Application?$filter=IsActiveEntity%20eq%20true&$top=1", timeout=60).json()["value"]
app = apps[0]
url = f"{b.RECRUIT}/Application(ApplicationId={app['ApplicationId']},IsActiveEntity=true)"
action = f"{url}/{b.NS_R}.setAIEvaluation"
body = {"Score": float(app["AiMatchScore"]), "Recommendation": app["AiRecommendation"], "Summary": app["AiSummary"]}
etag = b.s.get(url, timeout=60).headers.get("etag")
outdated = etag.replace(etag[-8:-1], "0000000") if etag else 'W/"outdated"'

checks = {
    "outdated ETag (If-Match)": {"x-csrf-token": b.CSRF, "If-Match": outdated},
    "no If-Match header": {"x-csrf-token": b.CSRF},
    "no CSRF token": {"If-Match": etag or "*"},
}
results = {}
for name, headers in checks.items():
    r = b.s.post(action, json=body, headers={**headers, "Content-Type": "application/json"}, timeout=60)
    msg = r.headers.get("x-csrf-token") if r.status_code == 403 else (r.json().get("error", {}).get("message", "") if "json" in r.headers.get("Content-Type", "") else r.text[:80])
    results[name] = {"status": r.status_code, "message": str(msg)[:120]}
    print(f"{name:<28} -> HTTP {r.status_code}  {str(msg)[:100]}")
after = b.s.get(url, timeout=60).json()
print("values unchanged:", float(after["AiMatchScore"]) == body["Score"] and after["AiRecommendation"] == body["Recommendation"])
(b.HERE / "security_checks.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
