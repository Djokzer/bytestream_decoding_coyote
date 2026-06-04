#!/usr/bin/env python3
"""Generate SVG figures from the Vivado ILA captures.

Two figures are produced:
  - ila_design1_signals.svg  : the four ILA signals of Design 1, to show that
    only tready of the input is constraining.
  - ila_tready_comparison.svg: tready of the input AXI-Stream on Design 1 vs
    Design 2 (both at 250 MHz).
"""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMGS = ROOT / "docs" / "report_pa" / "src" / "imgs"

D1 = ROOT / "design_1" / "assets" / "iladata.csv"
D2 = ROOT / "design_2" / "assets" / "250M" / "iladata.csv"

SAMPLES = 120  # post-trigger samples to plot

SIGNALS_4 = [
    ("recv", "tvalid", "tvalid (input)"),
    ("recv", "tready", "tready (input)"),
    ("send", "tvalid", "tvalid (output)"),
    ("send", "tready", "tready (output)"),
]


def find_col(header, iface, sig):
    needle_iface = f"axis_host_{iface}[0]"
    return next(i for i, c in enumerate(header)
                if needle_iface in c and sig in c)


def load_signals(path: Path, signals):
    """Return {(iface, sig): [values...]} aligned post-trigger."""
    with path.open() as f:
        r = csv.reader(f)
        header = next(r)
        next(r)  # radix row
        cols = {(iface, sig): find_col(header, iface, sig)
                for iface, sig, _ in signals}
        trig = header.index("TRIGGER")
        rows = [row for row in r if row]
    t_idx = next((n for n, row in enumerate(rows) if int(row[trig]) != 0), 0)
    window = rows[t_idx:t_idx + SAMPLES]
    return {k: [int(row[i]) for row in window] for k, i in cols.items()}


def waveform_path(values, x0, y_high, y_low, dx):
    pts = []
    for i, v in enumerate(values):
        y = y_high if v else y_low
        pts.append((x0 + i * dx, y))
        pts.append((x0 + (i + 1) * dx, y))
    return " ".join(f"{x:.2f},{y:.2f}" for x, y in pts)


def panel(title, values, ratio, y0, x0, plot_w, plot_h, ratio_label="high"):
    y_high = y0 + plot_h * 0.20
    y_low = y0 + plot_h * 0.80
    dx = plot_w / SAMPLES
    path = waveform_path(values, x0, y_high, y_low, dx)

    parts = [
        f'<text x="{x0}" y="{y0 - 10}" font-family="Inter, Arial, sans-serif" '
        f'font-size="14" font-weight="600" fill="#222">{title}</text>',
        f'<text x="{x0 + plot_w}" y="{y0 - 10}" font-family="Inter, Arial, sans-serif" '
        f'font-size="12" fill="#666" text-anchor="end">{ratio_label} for {ratio:.0%} of the window</text>',
        f'<rect x="{x0}" y="{y0}" width="{plot_w}" height="{plot_h}" '
        f'fill="#fafafa" stroke="#bbb" stroke-width="1"/>',
        f'<line x1="{x0}" y1="{y0 + plot_h/2}" x2="{x0 + plot_w}" y2="{y0 + plot_h/2}" '
        f'stroke="#ddd" stroke-dasharray="3 3"/>',
        f'<text x="{x0 - 8}" y="{y_high + 4}" font-family="Inter, Arial, sans-serif" '
        f'font-size="10" fill="#666" text-anchor="end">1</text>',
        f'<text x="{x0 - 8}" y="{y_low + 4}" font-family="Inter, Arial, sans-serif" '
        f'font-size="10" fill="#666" text-anchor="end">0</text>',
        f'<polyline points="{path}" fill="none" stroke="#1f77b4" stroke-width="1.6"/>',
    ]
    return "\n".join(parts)


def write_design1_signals():
    data = load_signals(D1, SIGNALS_4)

    W = 1100
    margin_l, margin_r = 90, 30
    plot_w = W - margin_l - margin_r
    plot_h = 70
    gap = 38
    top0 = 56
    H = top0 + len(SIGNALS_4) * (plot_h + gap) + 20

    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
        f'font-family="Inter, Arial, sans-serif">',
        f'<rect width="{W}" height="{H}" fill="white"/>',
        f'<text x="{W/2}" y="28" font-size="17" font-weight="700" '
        f'fill="#111" text-anchor="middle">'
        f'Design 1 — ILA capture of the four AXI-Stream handshake signals ({SAMPLES} post-trigger cycles)</text>',
    ]

    for i, (iface, sig, label) in enumerate(SIGNALS_4):
        values = data[(iface, sig)]
        ratio = sum(values) / len(values)
        y0 = top0 + i * (plot_h + gap)
        svg.append(panel(label, values, ratio, y0, margin_l, plot_w, plot_h))

    svg.append(f'<text x="{W/2}" y="{H - 4}" font-size="11" fill="#666" '
               f'text-anchor="middle">clock cycles (ILA samples)</text>')
    svg.append('</svg>')

    out = IMGS / "ila_design1_signals.svg"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(svg))
    ratios = {k: sum(v) / len(v) for k, v in data.items()}
    print(f"Wrote {out}")
    for k, r in ratios.items():
        print(f"  {k}: {r:.1%}")


def write_comparison():
    d1 = load_signals(D1, [("recv", "tready", "")])[("recv", "tready")]
    d2 = load_signals(D2, [("recv", "tready", "")])[("recv", "tready")]
    r1 = sum(d1) / len(d1)
    r2 = sum(d2) / len(d2)

    W, H = 1100, 480
    margin_l, margin_r = 60, 30
    plot_w = W - margin_l - margin_r
    plot_h = 140

    top1 = 60
    top2 = top1 + plot_h + 80

    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
        f'font-family="Inter, Arial, sans-serif">',
        f'<rect width="{W}" height="{H}" fill="white"/>',
        f'<text x="{W/2}" y="28" font-size="18" font-weight="700" '
        f'fill="#111" text-anchor="middle">'
        f'Input AXI-Stream tready — ILA capture over {SAMPLES} post-trigger cycles</text>',
        panel("Design 1 — 32-bit output, 250 MHz", d1, r1, top1, margin_l, plot_w, plot_h, ratio_label="tready high"),
        panel("Design 2 — 128-bit output, 250 MHz", d2, r2, top2, margin_l, plot_w, plot_h, ratio_label="tready high"),
        f'<text x="{W/2}" y="{H - 12}" font-size="12" fill="#666" text-anchor="middle">'
        f'clock cycles (ILA samples)</text>',
        '</svg>',
    ]

    out = IMGS / "ila_tready_comparison.svg"
    out.write_text("\n".join(svg))
    print(f"Wrote {out} (Design 1: {r1:.1%}, Design 2: {r2:.1%})")


if __name__ == "__main__":
    write_design1_signals()
    write_comparison()
