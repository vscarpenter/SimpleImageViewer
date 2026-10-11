"""Content-only local corpus scoring; independent of the app implementation.

Usage: python3 score-ocr.py result.jsonl output.json
Counts case-sensitive NFC, whitespace-delimited token occurrences separately
for returned descriptions, accepted OCR callbacks, and recorded perception.
An accepted callback can keep OCR available when description generation fails.
Duplicate cells count separately. Printed cell/line matches are supplementary
and sensitive to OCR segmentation.
"""
from collections import Counter
from pathlib import Path
import hashlib
import json
import sys
import unicodedata

ROOT = Path(__file__).parent
TRUTH = ROOT / "ocr-ground-truth.json"


def normalize(text):
    return " ".join(unicodedata.normalize("NFC", text).split())


def load_records(result_file):
    records = {}
    expected_count = None
    for line in Path(result_file).read_text().splitlines():
        record = json.loads(line)
        if record.get("kind") == "run":
            expected_count = record.get("count")
        if "file" in record and "status" in record:
            assert record["file"] not in records, "duplicate fixture result"
            records[record["file"]] = record
    if expected_count is not None:
        assert len(records) == expected_count, f"incomplete run: {len(records)}/{expected_count}"
    return records


def observations(record, field):
    if field not in record:
        return None
    return [normalize(value["text"]) for value in record[field].get("textObservations", [])]


def sources(record):
    result = record.get("result")
    returned = list(map(normalize, result.get("recognizedText", []))) if result is not None else None
    accepted = observations(record, "acceptedOCR")
    perception = observations(record, "perception")
    # Callback is the independent OCR path exposed by the new UI even when
    # generation throws. Perception is the recorded extraction evidence in
    # older successful runs. Missing historical error evidence stays unknown.
    extraction = accepted if accepted is not None else perception
    delivered = accepted if accepted is not None else (returned if returned is not None else perception)
    delivered_source = "acceptedOCR" if accepted is not None else (
        "result.recognizedText" if returned is not None else ("perception" if perception is not None else "unavailable"))
    return {
        "returned_description_ocr": returned,
        "accepted_callback_ocr": accepted,
        "recorded_extraction_ocr": extraction,
        "available_user_ocr": delivered,
        "available_user_ocr_source": delivered_source,
    }


def content_score(expected_lines, actual_lines):
    if actual_lines is None:
        actual_lines = []
    expected_tokens = Counter(" ".join(expected_lines).split())
    actual_tokens = Counter(" ".join(actual_lines).split())
    matched = expected_tokens & actual_tokens
    return {
        "exact_token_occurrences_recovered": sum(matched.values()),
        "expected_token_occurrences": sum(expected_tokens.values()),
        "missing_token_occurrences": list((expected_tokens - actual_tokens).elements()),
        "extra_token_occurrences": list((actual_tokens - expected_tokens).elements()),
        "all_content_recovered_without_extra_tokens": expected_tokens == actual_tokens,
        "exact_line_or_cell_matches_segmentation_sensitive": sum((Counter(expected_lines) & Counter(actual_lines)).values()),
        "expected_lines_or_cells": len(expected_lines),
        "recognized_text": actual_lines,
    }


def total_scores(cases, source):
    unknown_sources = source in ("accepted_callback_ocr", "recorded_extraction_ocr")
    observed_cases = [case for case in cases if not unknown_sources or case["source_availability"][source]]
    scored = [case["content_scores"][source] for case in observed_cases]
    return {
        "exact_token_occurrences_recovered": sum(case["exact_token_occurrences_recovered"] for case in scored),
        "expected_token_occurrences": sum(case["expected_token_occurrences"] for case in scored),
        "complete_content_cases": sum(case["all_content_recovered_without_extra_tokens"] for case in scored),
        "readable_cases": len(scored),
        "unobserved_source_cases": len(cases) - len(scored),
        "extra_token_occurrences": sum(len(case["extra_token_occurrences"]) for case in scored),
        "exact_line_or_cell_matches_segmentation_sensitive": sum(case["exact_line_or_cell_matches_segmentation_sensitive"] for case in scored),
        "expected_lines_or_cells": sum(case["expected_lines_or_cells"] for case in scored),
    }


def evaluate(result_file):
    truth = json.loads(TRUTH.read_text())
    records = load_records(result_file)
    cases = []
    for fixture in truth["readable_cases"]:
        name = fixture["file"]
        record = records.get(name, {})
        expected_lines = list(map(normalize, fixture["printed_lines_or_cells"]))
        text_sources = sources(record)
        scored = {source: content_score(expected_lines, text_sources[source]) for source in
                  ("returned_description_ocr", "accepted_callback_ocr", "recorded_extraction_ocr", "available_user_ocr")}
        cases.append({
            "file": name,
            "status": record.get("status", "missing"),
            "source_availability": {source: text_sources[source] is not None for source in scored},
            "available_user_ocr_source": text_sources["available_user_ocr_source"],
            "content_scores": scored,
        })
    no_text = []
    for name in truth["no_readable_text_cases"]:
        record = records.get(name, {})
        no_text.append({"file": name, "status": record.get("status", "missing"), "sources": sources(record)})
    totals = total_scores(cases, "returned_description_ocr")
    totals_by_source = {source: total_scores(cases, source) for source in cases[0]["content_scores"]}
    return {
        "version": 2,
        "result_file": str(Path(result_file).resolve()),
        "result_sha256": hashlib.sha256(Path(result_file).read_bytes()).hexdigest(),
        "truth_sha256": hashlib.sha256(TRUTH.read_bytes()).hexdigest(),
        "scope": "Ten fixed readable synthetic fixtures. This measures exact content recovery only, not general OCR accuracy or layout correctness.",
        "totals": totals, "totals_by_source": totals_by_source,
        "available_ocr_after_generation_error": [case["file"] for case in cases
            if case["status"] == "error" and case["content_scores"]["available_user_ocr"]["recognized_text"]],
        "extraction_unobserved_cases": [case["file"] for case in cases
            if not case["source_availability"]["recorded_extraction_ocr"]],
        "cases": cases, "no_text_cases": no_text,
    }


def compare(baseline_file, updated_file):
    baseline = evaluate(baseline_file)
    updated = evaluate(updated_file)
    old_cases = {case["file"]: case for case in baseline["cases"]}
    new_cases = {case["file"]: case for case in updated["cases"]}
    comparable = [name for name in old_cases if old_cases[name]["source_availability"]["recorded_extraction_ocr"]
                  and new_cases[name]["source_availability"]["recorded_extraction_ocr"]]
    comparable_old = [old_cases[name] for name in comparable]
    comparable_new = [new_cases[name] for name in comparable]
    visible_gains = [name for name, case in old_cases.items()
                    if not case["source_availability"]["available_user_ocr"]
                    and new_cases[name]["content_scores"]["available_user_ocr"]["recognized_text"]]
    return {
        "version": 1,
        "baseline": baseline,
        "updated": updated,
        "user_visible_content_delivery": {
            "baseline": baseline["totals_by_source"]["available_user_ocr"],
            "updated": updated["totals_by_source"]["available_user_ocr"],
            "newly_available_cases": visible_gains,
            "interpretation": "Delivery recovery includes OCR preserved after generation errors. Do not call delivery gain underlying OCR accuracy improvement.",
        },
        "paired_extraction_correctness_where_observed_in_both": {
            "cases": comparable,
            "excluded_historical_unobserved_extraction": baseline["extraction_unobserved_cases"],
            "baseline": total_scores(comparable_old, "recorded_extraction_ocr"),
            "updated": total_scores(comparable_new, "recorded_extraction_ocr"),
            "interpretation": "Compare only extraction evidence available in both runs. Historical failed cases have unknown extraction, not a measured recognition failure.",
        },
    }


if __name__ == "__main__":
    assert len(sys.argv) in (3, 5), "provide result.jsonl output.json, or --compare baseline.jsonl updated.jsonl output.json"
    if len(sys.argv) == 5:
        assert sys.argv[1] == "--compare"
        output = compare(sys.argv[2], sys.argv[3])
        destination = sys.argv[4]
        compact = {key: output[key] for key in ("user_visible_content_delivery", "paired_extraction_correctness_where_observed_in_both")}
    else:
        output = evaluate(sys.argv[1])
        destination = sys.argv[2]
        compact = output["totals_by_source"]
    Path(destination).write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(compact))
