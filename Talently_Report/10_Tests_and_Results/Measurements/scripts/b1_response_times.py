"""B1 - Response times of the main operations (Chapter 5, Table 5.4).

Uses the same SAP session cookie as the portal (read from FrontEnd/vite.config.js, method unchanged) and calls the
OData V4 services directly, like the Fiori apps and the portal do.

  1. Job offers list (HR cockpit)          GET JobOffer list query, 10 runs (read only)
  2. Submitting an application             POST Candidate(...)/applyToJob, 5 runs
  3. AI evaluation of one resume (portal)  offer read + POST /evaluate/score + setAIEvaluation, 3 runs
  4. Hiring                                POST Onboarding(...)/approveAndCreateEmployee, 3 runs

Steps 2-4 run on temporary records created for the test and named "PERF TEST" (one job offer with 3 positions and
one pipeline step, 5 candidates). Everything is deleted at the end, even when a step fails, and a final check
lists anything that could not be deleted. The demo data of the walkthrough is never modified.

Usage:  python b1_response_times.py            (all measurements)
        python b1_response_times.py --check    (only checks the session and the service metadata)
Needs the AI service on http://localhost:8000 for step 3.
"""
import json
import re
import statistics
import sys
import time
from datetime import date, timedelta
from pathlib import Path

import requests

HERE = Path(__file__).resolve().parent
VITE = Path(r"C:\Users\pc\Desktop\SAP_test\FrontEnd\vite.config.js")
RESULTS = HERE / "b1_results.json"
AI_URL = "http://localhost:8000/evaluate/score"
RESUME_URL = "https://drive.google.com/file/d/1QAQMS92Sq8xmyvTI2m3MQmRX6RIUhsvy/view"  # CV B (Salma), public link
TAG = "PERF TEST"

vite = VITE.read_text(encoding="utf-8")
HOST = re.search(r"target:\s*'([^']+)'", vite).group(1)
COOKIE = re.search(r"setHeader\('Cookie',\s*'([^']+)'", vite).group(1)
RECRUIT = f"{HOST}/sap/opu/odata4/sap/zui_hcm_recruit/srvd/sap/zui_hcm_recruit/0001"
PA = f"{HOST}/sap/opu/odata4/sap/zui_hcm_pa/srvd/sap/zui_hcm_pa/0001"
NS_R = "com.sap.gateway.srvd.zui_hcm_recruit.v0001"
NS_P = "com.sap.gateway.srvd.zui_hcm_pa.v0001"

s = requests.Session()
s.headers.update({"Cookie": COOKIE, "Accept": "application/json"})


class SessionExpired(Exception):
    pass


def call(method, url, body=None, etag=None, timed=False):
    headers = {}
    if method != "GET":
        headers["x-csrf-token"] = CSRF
        headers["Content-Type"] = "application/json"
        headers["If-Match"] = etag or "*"  # the service requires a conditional request for every write
    start = time.perf_counter()
    r = s.request(method, url, json=body, headers=headers, timeout=120)
    ms = (time.perf_counter() - start) * 1000
    if "text/html" in r.headers.get("Content-Type", "") and "oauth/authorize" in r.text:
        raise SessionExpired("The SAP session cookie has expired: update it in FrontEnd/vite.config.js.")
    if r.status_code >= 400:
        raise RuntimeError(f"{method} {url.replace(HOST, '')} -> {r.status_code}: {r.text[:400]}")
    data = r.json() if r.content and "json" in r.headers.get("Content-Type", "") else {}
    return (data, ms, r.headers) if timed else (data, r.headers)


def fetch_csrf():
    r = s.get(f"{RECRUIT}/", headers={"x-csrf-token": "Fetch"}, timeout=60)
    if "oauth/authorize" in r.text:
        raise SessionExpired("The SAP session cookie has expired: update it in FrontEnd/vite.config.js.")
    return r.headers["x-csrf-token"]


def etag_of(url):
    data, headers = call("GET", url)
    return headers.get("etag") or data.get("@odata.etag") or "*"


def stats(values):
    return {"runs": len(values), "mean": round(statistics.mean(values), 1), "median": round(statistics.median(values), 1),
            "min": round(min(values), 1), "max": round(max(values), 1), "values": [round(v, 1) for v in values]}


def check_metadata():
    for svc, needed in ((RECRUIT, ["JobOffer", "Application", "Candidate", "Onboarding", "applyToJob", "acceptToPost",
                                   "setAIEvaluation", "submitForm", "approveAndCreateEmployee", "publishOffer"]),
                        (PA, ["Employee"])):
        r = s.get(f"{svc}/$metadata", headers={"Accept": "application/xml"}, timeout=60)
        if "oauth/authorize" in r.text:
            raise SessionExpired("The SAP session cookie has expired: update it in FrontEnd/vite.config.js.")
        missing = [n for n in needed if f'Name="{n}"' not in r.text]
        if missing:
            raise RuntimeError(f"Not found in {svc.split('/sap/')[-1]} metadata: {missing}")
    print("Session and metadata OK")


# ---------------------------------------------------------------------------------------------------------------------
def measure_list(results):
    url = (f"{RECRUIT}/JobOffer?$count=true&$filter=(IsActiveEntity%20eq%20false%20or%20SiblingEntity/IsActiveEntity"
           f"%20eq%20null)&$select=OfferId,Title,PositionTitle,Department,Status,StatusText,PositionsNeeded,"
           f"PositionsFilled,ValidUntil,IsActiveEntity,HasDraftEntity,HasActiveEntity&$skip=0&$top=30")
    call("GET", url)  # warm-up (not counted)
    times = [call("GET", url, timed=True)[1] for _ in range(10)]
    results["job_offers_list_ms"] = stats(times)
    print("job offers list:", results["job_offers_list_ms"])


def create_test_offer(created):
    today = date.today()
    body = {"Title": f"{TAG} - response time measurement", "Department": "SAP Development",
            "Description": "Temporary offer created by the B1 measurement script; deleted automatically.",
            "RequiredSkills": "ABAP, RAP", "PositionsNeeded": 3, "Location": "Test",
            "AppDeadline": str(today + timedelta(days=30)), "ValidUntil": str(today + timedelta(days=60))}
    draft, _ = call("POST", f"{RECRUIT}/JobOffer", body)
    offer_id = draft["OfferId"]
    created["offer"] = offer_id
    draft_url = f"{RECRUIT}/JobOffer(OfferId={offer_id},IsActiveEntity=false)"
    call("POST", f"{draft_url}/_Steps", {"StepOrder": 1, "StepName": "Interview", "StepType": "INTERV"})
    call("POST", f"{draft_url}/{NS_R}.Activate", {})
    active_url = f"{RECRUIT}/JobOffer(OfferId={offer_id},IsActiveEntity=true)"
    call("POST", f"{active_url}/{NS_R}.publishOffer", {}, etag=etag_of(active_url))
    return offer_id


def measure_apply(results, created, offer_id):
    times = []
    for i in range(1, 6):
        cand, _ = call("POST", f"{RECRUIT}/Candidate", {"FirstName": "Perf", "LastName": f"Test {i}",
                                                      "Email": f"perf.test{i}@example.com", "Phone": "0000000000",
                                                      "Cin": "PERFTEST"})
        cid = cand["CandidateId"]
        created["candidates"].append(cid)
        payload = {"OfferId": offer_id, "ResumeUrl": RESUME_URL, "CoverLetter": f"{TAG}", "NoticePeriod": "30",
                   "SalaryExpectation": 10000, "CurrencyCode": "USD"}
        _, ms, _ = call("POST", f"{RECRUIT}/Candidate({cid})/{NS_R}.applyToJob", payload,
                        etag=etag_of(f"{RECRUIT}/Candidate({cid})"), timed=True)
        times.append(ms)
    results["apply_to_job_ms"] = stats(times)
    print("applyToJob:", results["apply_to_job_ms"])


def application_of(offer_id, cid):
    data, _ = call("GET", f"{RECRUIT}/Application?$filter=OfferId%20eq%20{offer_id}%20and%20CandidateId%20eq%20{cid}"
                          f"%20and%20IsActiveEntity%20eq%20true")
    return data["value"][0]


def measure_ai(results, created, offer_id):
    """Same steps as evaluateApplication() in FrontEnd/src/api.js."""
    times, ai_times, scores = [], [], []
    for cid in created["candidates"][3:5] + created["candidates"][:1]:
        start = time.perf_counter()
        offer, _ = call("GET", f"{RECRUIT}/JobOffer(OfferId={offer_id},IsActiveEntity=true)")
        offer_info = "\n".join(x for x in [offer["Title"], offer.get("Description"),
                                           f"Required skills: {offer.get('RequiredSkills')}"] if x)
        ai_start = time.perf_counter()
        ai = requests.post(AI_URL, json={"gdrive_url": RESUME_URL, "offer_info": offer_info}, timeout=600).json()
        ai_times.append(time.perf_counter() - ai_start)
        app = application_of(offer_id, cid)
        app_url = f"{RECRUIT}/Application(ApplicationId={app['ApplicationId']},IsActiveEntity=true)"
        summary = "\n".join([f"+ {x}" for x in ai.get("key_strengths", [])] +
                            [f"- {x}" for x in ai.get("areas_for_improvement", [])])[:1000]
        call("POST", f"{app_url}/{NS_R}.setAIEvaluation",
             {"Score": round(float(ai["score"]), 2), "Recommendation": ai["recommendation"][:20], "Summary": summary},
             etag=etag_of(app_url))
        times.append(time.perf_counter() - start)
        scores.append(ai["score"])
    results["ai_evaluation_end_to_end_s"] = stats(times)
    results["ai_service_only_s"] = stats(ai_times)
    results["ai_scores"] = scores
    print("AI end to end (s):", results["ai_evaluation_end_to_end_s"])


def measure_hire(results, created, offer_id):
    times = []
    today = date.today()
    for i, cid in enumerate(created["candidates"][:3], 1):
        app = application_of(offer_id, cid)
        app_url = f"{RECRUIT}/Application(ApplicationId={app['ApplicationId']},IsActiveEntity=true)"
        call("POST", f"{app_url}/{NS_R}.acceptToPost",
             {"OfferedSalary": 120000, "StartDate": str(today + timedelta(days=21)), "Notes": TAG},
             etag=etag_of(app_url))
        forms, _ = call("GET", f"{RECRUIT}/Onboarding?$filter=ApplicationId%20eq%20{app['ApplicationId']}"
                               f"%20and%20IsActiveEntity%20eq%20true")
        form_id = forms["value"][0]["FormId"]
        created["forms"].append(form_id)
        active = f"{RECRUIT}/Onboarding(FormId={form_id},IsActiveEntity=true)"
        draft = f"{RECRUIT}/Onboarding(FormId={form_id},IsActiveEntity=false)"
        call("POST", f"{active}/{NS_R}.Edit", {"PreserveChanges": True}, etag=etag_of(active))
        call("PATCH", draft, {"FirstName": "Perf", "LastName": f"Test {i}", "DateOfBirth": "1999-01-01",
                              "NationalId": f"PERF{i:04d}", "Nationality": "Moroccan", "Address": "Test address",
                              "Phone": "0000000000", "PersonalEmail": f"perf.test{i}@example.com",
                              "BankName": "Test bank", "BankAccount": "0000", "Iban": "MA00TEST",
                              "EmergencyName": "Test contact", "EmergencyPhone": "0000000000",
                              "EmergencyRelation": "Sibling"}, etag="*")
        call("POST", f"{draft}/{NS_R}.Activate", {})
        call("POST", f"{active}/{NS_R}.submitForm", {}, etag=etag_of(active))
        _, ms, _ = call("POST", f"{active}/{NS_R}.approveAndCreateEmployee", {}, etag=etag_of(active), timed=True)
        times.append(ms)
        form, _ = call("GET", active)
        if form.get("EmployeeId"):
            created["employees"].append(form["EmployeeId"])
    results["approve_and_create_employee_ms"] = stats(times)
    print("approveAndCreateEmployee:", results["approve_and_create_employee_ms"])


def cleanup(created):
    """Deletes every record created by this script; returns what could not be deleted."""
    left = []
    try:  # employees of the test, also when the form did not return the new employee id
        emps, _ = call("GET", f"{PA}/Employee?$filter=FirstName%20eq%20'Perf'%20and%20IsActiveEntity%20eq%20true")
        for e in emps.get("value", []):
            if str(e.get("LastName", "")).startswith("Test ") and e["EmployeeId"] not in created["employees"]:
                created["employees"].append(e["EmployeeId"])
    except Exception as e:
        left.append(f"employee lookup: {str(e)[:200]}")
    targets = ([(f"{PA}/Employee(EmployeeId={e},IsActiveEntity=true)", f"employee {e}") for e in created["employees"]] +
               [(f"{RECRUIT}/Onboarding(FormId={f},IsActiveEntity=true)", f"onboarding form {f}") for f in created["forms"]] +
               ([(f"{RECRUIT}/JobOffer(OfferId={created['offer']},IsActiveEntity=false)", "offer draft")] if created["offer"] else []) +
               ([(f"{RECRUIT}/JobOffer(OfferId={created['offer']},IsActiveEntity=true)", "test offer")] if created["offer"] else []) +
               [(f"{RECRUIT}/Candidate({c})", f"candidate {c}") for c in created["candidates"]])
    for url, label in targets:
        try:
            r = s.get(url, timeout=60)
            if r.status_code == 404:
                continue
            if "IsActiveEntity=false" in url:  # a draft is removed with Discard, not DELETE
                call("POST", f"{url}/{NS_R}.Discard", {})
                continue
            etag = r.headers.get("etag") or "*"
            call("DELETE", url, etag=etag)
        except Exception as e:  # keep going, report at the end
            if "404" not in str(e):
                left.append(f"{label}: {str(e)[:200]}")
    # final check by name: nothing named PERF TEST may remain
    offers, _ = call("GET", f"{RECRUIT}/JobOffer?$filter=startswith(Title,'{TAG.replace(' ', '%20')}')")
    cands, _ = call("GET", f"{RECRUIT}/Candidate?$filter=startswith(Email,'perf.test')")
    left += [f"offer still present: {o['OfferId']}" for o in offers.get("value", [])]
    left += [f"candidate still present: {c['CandidateId']}" for c in cands.get("value", [])]
    return left


if __name__ == "__main__":
    try:
        CSRF = fetch_csrf()
        check_metadata()
    except SessionExpired as e:
        sys.exit(str(e))
    if "--check" in sys.argv:
        sys.exit(0)

    results = {"measured_at": time.strftime("%Y-%m-%d %H:%M"), "host": HOST.split("//")[1].split(".")[0]}
    created = {"offer": None, "candidates": [], "forms": [], "employees": []}
    try:
        measure_list(results)
        offer_id = create_test_offer(created)
        measure_apply(results, created, offer_id)
        measure_ai(results, created, offer_id)
        measure_hire(results, created, offer_id)
    except Exception as e:
        results["error"] = str(e)[:600]
        print("ERROR:", results["error"])
    finally:
        results["cleanup_left"] = cleanup(created)
        RESULTS.write_text(json.dumps(results, indent=2), encoding="utf-8")
        print("cleanup:", "everything deleted" if not results["cleanup_left"] else results["cleanup_left"])
