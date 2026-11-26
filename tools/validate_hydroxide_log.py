#!/usr/bin/env python3
"""Check JSONL integrity, not completeness of network capture. Standard library only."""
import argparse
import json
from collections import Counter


def validate(path):
    counts = Counter()
    issues = []
    previous = None
    incomplete = 0
    with open(path, encoding="utf-8") as stream:
        for number, line in enumerate(stream, 1):
            try:
                item = json.loads(line)
                if not isinstance(item, dict):
                    raise ValueError("record is not an object")
            except (ValueError, TypeError) as exc:
                issues.append(f"line {number}: {exc}")
                continue
            counts[item.get("kind", "missing_kind")] += 1
            seq = item.get("sequence")
            if isinstance(seq, int):
                if previous is None and seq != 1:
                    issues.append(f"line {number}: first sequence is {seq}, not 1")
                if previous is not None and seq != previous + 1:
                    issues.append(f"line {number}: sequence {previous} -> {seq}")
                previous = seq
            else:
                issues.append(f"line {number}: missing/incompatible sequence")
            stack = [item.get("data")]
            cut = False
            while stack:
                value = stack.pop()
                if isinstance(value, list):
                    stack.extend(value)
                elif isinstance(value, dict):
                    cut = cut or bool(value.get("truncated")) or bool(value.get("bytesError"))
                    if value.get("kind") == "buffer" and not value.get("bytes"):
                        cut = True
                    stack.extend(value.values())
            incomplete += int(cut)
    warnings = []
    if not counts["session_stop"]:
        warnings.append("No session_stop: final flush/clean shutdown is unverified")
    if not counts["remote_call"]:
        warnings.append("No standard outgoing calls: outgoing coverage is UNVERIFIED")
    warnings.append("Valid JSON and installed hooks do NOT prove complete capture")
    return dict(counts=counts, integrity_issues=issues,
                incomplete_records=incomplete, warnings=warnings)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path")
    args = parser.parse_args()
    report = validate(args.path)
    print(json.dumps(report, indent=2))
    raise SystemExit(bool(report["integrity_issues"] or report["incomplete_records"]))
