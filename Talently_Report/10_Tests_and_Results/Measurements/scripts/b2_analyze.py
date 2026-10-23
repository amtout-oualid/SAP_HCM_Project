"""Summarizes b2_runs.jsonl into the figures of Table 5.3 (printed and written to b2_summary.json)."""
import json
import statistics as st
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
PRICE_IN, PRICE_OUT = 0.15, 0.60  # USD per million tokens, OpenAI list price of gpt-4o-mini

import sys  # noqa: E402
SOURCE = sys.argv[1] if len(sys.argv) > 1 else "b2_runs.jsonl"
runs = [json.loads(l) for l in (HERE / SOURCE).read_text(encoding="utf-8").splitlines()]
ok = [r for r in runs if not r.get("error")]
print(f"{len(runs)} runs, {len(runs) - len(ok)} errors")
by = defaultdict(list)
for r in ok:
    by[(r["test"], r["file"])].append(r)


def desc(rs):
    sc = [r["final_score"] for r in rs]
    recs = [r["recommendation"] for r in rs]
    return {"runs": len(sc), "scores": sc, "mean": round(st.mean(sc), 1),
            "sd": round(st.stdev(sc), 1) if len(sc) > 1 else 0.0, "min": min(sc), "max": max(sc),
            "recommendations": sorted(set(recs)),
            "recommendation_counts": ", ".join(f"{x} {recs.count(x)}/{len(recs)}" for x in sorted(set(recs)))}


summary = {}
# known-level ranking
kl = {f.split("_")[1]: desc(rs) for (t, f), rs in by.items() if t == "known_level"}
order_ok = all(a > b > c for a, b, c in zip(kl["A"]["scores"], kl["B"]["scores"], kl["C"]["scores"]))
summary["known_level"] = {"per_cv": kl, "ranking_A_gt_B_gt_C_in_every_run": order_ok}

# consistency: CV B PDF (cached GitHub) 5 runs
cons = by[("consistency", "CV_B_Salma_Idrissi.pdf")]
cat_ranges = {}
for cat in cons[0]["scores"]:
    vals = [r["scores"][cat] for r in cons]
    cat_ranges[cat] = (min(vals), max(vals))
summary["consistency"] = {**desc(cons), "category_min_max": cat_ranges,
                          "bonus": sorted({r["bonus"] for r in cons}), "deductions": sorted({r["deductions"] for r in cons})}

# format robustness: PDF (consistency runs) vs DOCX vs TXT
fmt = {"pdf": desc(cons), "docx": desc(by[("format", "CV_B_Salma_Idrissi.docx")]),
       "txt": desc(by[("format", "CV_B_Salma_Idrissi.txt")])}
means = [v["mean"] for v in fmt.values()]
summary["format"] = {**fmt, "max_difference_of_means": round(max(means) - min(means), 1),
                     "all_recommendations": sorted({x for v in fmt.values() for x in v["recommendations"]})}

# fairness: original (consistency runs) vs variant
var_runs = by[("fairness", "CV_B_variant_Youssef_Alaoui.pdf")]
var = desc(var_runs)
o, v = desc(cons), var
se = (o["sd"] ** 2 / o["runs"] + v["sd"] ** 2 / v["runs"]) ** 0.5
summary["fairness"] = {"original": o, "variant": v, "difference_of_means": round(v["mean"] - o["mean"], 1),
                       "welch_t": round((v["mean"] - o["mean"]) / se, 2) if se else None,
                       "open_source_scores_original": [r["scores"]["open_source"] for r in cons],
                       "open_source_scores_variant": [r["scores"]["open_source"] for r in var_runs],
                       "consider_or_better": {"original": sum(r["recommendation"] != "DO_NOT_HIRE" for r in cons),
                                              "variant": sum(r["recommendation"] != "DO_NOT_HIRE" for r in var_runs)}}

# latency and cost: full pipeline runs (known level, GitHub fetched each time)
full = [r for r in ok if not r["github_cached"]]
lat = {}
for cv in ("A", "B", "C"):
    rs = [r for r in full if r["file"].split("_")[1] == cv]
    lat[cv] = {"seconds_mean": round(st.mean(r["seconds"] for r in rs), 1),
               "prompt_tokens_mean": round(st.mean(r["prompt_tokens"] for r in rs)),
               "completion_tokens_mean": round(st.mean(r["completion_tokens"] for r in rs)),
               "llm_calls": sorted({r["llm_calls"] for r in rs})}
pt = st.mean(r["prompt_tokens"] for r in full)
ct = st.mean(r["completion_tokens"] for r in full)
cost = (pt * PRICE_IN + ct * PRICE_OUT) / 1e6
summary["latency_cost"] = {"per_cv": lat, "seconds_mean_all": round(st.mean(r["seconds"] for r in full), 1),
                           "seconds_min": min(r["seconds"] for r in full), "seconds_max": max(r["seconds"] for r in full),
                           "prompt_tokens_mean": round(pt), "completion_tokens_mean": round(ct),
                           "cost_usd_per_resume": round(cost, 5), "cost_usd_per_1000_resumes": round(cost * 1000, 2)}
total_cost = sum(r["prompt_tokens"] * PRICE_IN + r["completion_tokens"] * PRICE_OUT for r in runs) / 1e6
summary["total_cost_of_this_test_session_usd"] = round(total_cost, 4)

(HERE / SOURCE.replace("runs", "summary").replace(".jsonl", ".json")).write_text(json.dumps(summary, indent=2),
                                                                                 encoding="utf-8")
print(json.dumps(summary, indent=2))
