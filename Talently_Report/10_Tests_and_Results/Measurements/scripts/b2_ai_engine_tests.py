"""B2 - Capability tests of the AI evaluation engine (Chapter 5, Table 5.3).

Runs the real evaluation pipeline of the FastAPI service (routers.evaluate._execute_pipeline, the same code
path as POST /evaluate/upload) on local resume files, and records for every run the score, the category
scores, the recommendation, the duration, and the OpenAI token usage of every LLM call.

Tests
  known_level  CV A (strong), B (medium), C (weak) - 3 full runs each (GitHub fetched every time)
               -> expected ranking and latency/cost per resume
  consistency  CV B as PDF - 5 runs
  format       CV B as DOCX and TXT - 3 runs each (compared with the 5 PDF runs)
  fairness     CV B with another name/gender, city and university - 3 runs
For consistency, format and fairness, the GitHub data of the candidate is fetched once and reused, so that
the only varying input is the one under test (the language model itself stays non-deterministic).

Results are appended to b2_runs.jsonl (one JSON object per run); an interrupted session resumes where it stopped.
Usage:  python b2_ai_engine_tests.py
"""
import json
import logging
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
API = Path(r"C:\Users\pc\Desktop\SAP_test\VERSION_COMPARE\DELIVERY\sap-evaluator-api")
CVS = HERE / "cvs"
RESULTS = HERE / os.environ.get("B2_RESULTS", "b2_runs.jsonl")  # b2_runs_v2.jsonl = engine with anonymized scoring input

OFFER_INFO = "\n".join([  # same text as the portal sends for the offer used in the walkthrough
    "SAP ABAP Developer (RAP)",
    "Join our SAP team to build cloud applications with ABAP RAP, CDS and Fiori Elements on SAP BTP.",
    "Required skills: ABAP, RAP, CDS, Fiori Elements, SAP BTP, Git",
    "Experience level: Mid Level",
])

sys.path.insert(0, str(API))
os.chdir(API)
logging.basicConfig(level=logging.WARNING)

import requests  # noqa: E402

LLM_CALLS = []
_post = requests.post


def _counting_post(url, *args, **kwargs):
    """Wraps the HTTP call of the LLM client to record the token usage returned by OpenAI."""
    response = _post(url, *args, **kwargs)
    if "chat/completions" in str(url):
        try:
            usage = response.json().get("usage") or {}
        except ValueError:
            usage = {}
        LLM_CALLS.append((usage.get("prompt_tokens", 0), usage.get("completion_tokens", 0)))
    return response


requests.post = _counting_post

from fastapi import HTTPException  # noqa: E402
from routers.evaluate import _execute_pipeline  # noqa: E402
import services.github_enricher as github_enricher  # noqa: E402

GITHUB_CACHE = {}
USE_GITHUB_CACHE = False
_enrich = github_enricher.GitHubEnricher.enrich_candidate


def _enrich_with_cache(self, github_url, position_title="Software Engineering Intern"):
    # keyed by user name: the LLM does not always write the profile URL the same way
    key = (github_enricher.extract_github_username(github_url) or github_url).lower()
    if USE_GITHUB_CACHE and key in GITHUB_CACHE:
        return json.loads(json.dumps(GITHUB_CACHE[key]))
    data = _enrich(self, github_url, position_title=position_title)
    GITHUB_CACHE[key] = json.loads(json.dumps(data))
    return data


github_enricher.GitHubEnricher.enrich_candidate = _enrich_with_cache

PLAN = []
for run in range(1, 4):
    for cv in ("CV_A_Yassine_Bennani.pdf", "CV_B_Salma_Idrissi.pdf", "CV_C_Omar_Tazi.pdf"):
        PLAN.append(("known_level", cv, run, False))
for run in range(1, 6):
    PLAN.append(("consistency", "CV_B_Salma_Idrissi.pdf", run, True))
for run in range(1, 6):
    for cv in ("CV_B_Salma_Idrissi.docx", "CV_B_Salma_Idrissi.txt", "CV_B_variant_Youssef_Alaoui.pdf"):
        if run <= 3 or "variant" in cv:  # 3 runs per format, 5 runs for the fairness variant (as for the original)
            PLAN.append(("format" if "Salma" in cv else "fairness", cv, run, True))
# second series: 5 more runs of the original and of the variant, alternated (10 runs each in total)
for run in range(6, 11):
    PLAN.append(("consistency", "CV_B_Salma_Idrissi.pdf", run, True))
    PLAN.append(("fairness", "CV_B_variant_Youssef_Alaoui.pdf", run, True))


def done_keys():
    if not RESULTS.exists():
        return set()
    keys = set()
    for line in RESULTS.read_text(encoding="utf-8").splitlines():
        r = json.loads(line)
        if not r.get("error"):
            keys.add((r["test"], r["file"], r["run"]))
    return keys


def run_one(test, file, run, cached):
    global USE_GITHUB_CACHE
    USE_GITHUB_CACHE = cached
    LLM_CALLS.clear()
    record = {"test": test, "file": file, "run": run, "github_cached": cached}
    start = time.time()
    try:
        result = _execute_pipeline(file_bytes=(CVS / file).read_bytes(), filename=file,
                                   role_name="software_engineering_intern", offer_info=OFFER_INFO)
        record.update({
            "final_score": result["final_score"],
            "percentage": result["percentage"],
            "recommendation": result["recommendation"],
            "scores": {k: v.get("score") for k, v in (result.get("scores") or {}).items()},
            "bonus": (result.get("bonus_points") or {}).get("total"),
            "deductions": (result.get("deductions") or {}).get("total"),
            "candidate_name": result["candidate_name"],
            "github": result.get("resolved_github_url"),
            "key_strengths": result.get("key_strengths"),
            "areas_for_improvement": result.get("areas_for_improvement"),
        })
    except HTTPException as e:
        record["error"] = str(e.detail)
    except Exception as e:  # recorded, the session continues
        record["error"] = f"{type(e).__name__}: {e}"
    record["seconds"] = round(time.time() - start, 2)
    record["llm_calls"] = len(LLM_CALLS)
    record["prompt_tokens"] = sum(p for p, _ in LLM_CALLS)
    record["completion_tokens"] = sum(c for _, c in LLM_CALLS)
    with RESULTS.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")
    return record


if __name__ == "__main__":
    finished = done_keys()
    todo = [p for p in PLAN if (p[0], p[1], p[2]) not in finished]
    print(f"{len(PLAN) - len(todo)} runs already done, {len(todo)} to go", flush=True)
    for i, (test, file, run, cached) in enumerate(todo, 1):
        if cached and not GITHUB_CACHE:  # warm the GitHub cache with one uncounted fetch
            _enrich_with_cache(github_enricher.GitHubEnricher(), "https://github.com/amtout-oualid",
                               position_title="Software Engineering Intern at SAP")
        r = run_one(test, file, run, cached)
        status = r.get("error") or f"{r['final_score']:>5} {r['recommendation']:<12}"
        print(f"[{i:>2}/{len(todo)}] {test:<11} {file:<34} run {run}  {status}  "
              f"{r['seconds']:>5.1f}s  {r['llm_calls']} calls  {r['prompt_tokens']}+{r['completion_tokens']} tokens",
              flush=True)
