#!/usr/bin/env python3
"""Compute the fraction of cycles each tvalid/tready signal is high from a Vivado ILA CSV export."""

import csv
import re
import sys
from pathlib import Path


def short_name(col: str) -> str:
    """Shorten a Vivado signal path to the last component."""
    # e.g. inst_shell/.../axis_host_recv[0]\.tvalid -> axis_host_recv[0].tvalid
    col = re.sub(r"\\+\.", ".", col)
    parts = re.split(r"[/]", col)
    return parts[-1]


def main(csv_path: str) -> None:
    path = Path(csv_path)
    with path.open(newline="") as f:
        reader = csv.reader(f)
        header = next(reader)
        _radix = next(reader)  # second row is radix info, skip it
        rows = list(reader)

    # Find columns whose short name contains tvalid or tready
    targets = {
        i: short_name(col)
        for i, col in enumerate(header)
        if re.search(r"tvalid|tready", col, re.IGNORECASE)
    }

    if not targets:
        print("No tvalid/tready columns found.")
        sys.exit(1)

    trigger_col = header.index("TRIGGER")
    trigger_idx = next(
        (n for n, r in enumerate(rows) if r and int(r[trigger_col]) != 0), 0
    )

    counts = {i: 0 for i in targets}
    total = 0

    for row in rows[trigger_idx:]:
        if not row:
            continue
        total += 1
        for i in targets:
            if i < len(row) and int(row[i], 16) != 0:
                counts[i] += 1

    print(f"File: {path.resolve()}")
    print(f"Total samples: {total}  (post-trigger, starting at sample {trigger_idx})\n")

    # Group by interface (everything before the last dot-separated field)
    def interface(name: str) -> str:
        return name.rsplit(".", 1)[0] if "." in name else name

    current_iface = None
    print(f"{'Signal':<20} {'High cycles':>12} {'Ratio':>8}")
    print("-" * 42)
    for i, name in targets.items():
        iface = interface(name)
        if iface != current_iface:
            if current_iface is not None:
                print()
            print(f"  [{iface}]")
            current_iface = iface
        signal = name.rsplit(".", 1)[-1]
        high = counts[i]
        ratio = high / total if total else 0.0
        print(f"    {signal:<16} {high:>12} {ratio:>8.3%}")


if __name__ == "__main__":
    csv_file = sys.argv[1] if len(sys.argv) > 1 else "design_1/assets/iladata.csv"
    main(csv_file)