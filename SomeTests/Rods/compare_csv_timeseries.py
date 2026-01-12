import csv
import math
import os
from pathlib import Path

try:
    import matplotlib.pyplot as plt
except ModuleNotFoundError:
    plt = None


CSV_PATHS = [
    "fuel_rods/SomeTests/Rods/3Dfilm/3DRod_csv.csv",
    "fuel_rods/SomeTests/Rods/3DRod/3DRod_csv.csv",
    "fuel_rods/SomeTests/Rods/GeneralizedPlaneStrian/GeneralizedPlaneStrian_csv.csv",
    "fuel_rods/SomeTests/Rods/PlainStress/PlainStress_csv.csv",
    "fuel_rods/SomeTests/Rods/PlaneStrain/PlaneStrain_csv.csv"
]

PLOTS = [
    ("T_avg", "T_avg"),
    ("hoop_stress_max", "hoop_stress_max"),
    ("max_principal_avg", "max_principal_avg"),
    ("strain_energy_total", "strain_energy_total"),
]


def load_csv(path):
    path = Path(path)
    with path.open("r", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = [name.lstrip("# ").strip() for name in reader.fieldnames]
        data = {name: [] for name in fieldnames}
        for row in reader:
            for raw_key, value in row.items():
                key = raw_key.lstrip("# ").strip()
                if value is None or value == "":
                    continue
                data[key].append(float(value))
    return data


def _nice_ticks(vmin, vmax, nticks=5):
    if vmin == vmax:
        if vmin == 0:
            return [0.0]
        return [vmin]
    span = abs(vmax - vmin)
    raw_step = span / max(nticks - 1, 1)
    exp = math.floor(math.log10(raw_step)) if raw_step > 0 else 0
    base = 10**exp
    for m in (1, 2, 5, 10):
        step = m * base
        if step >= raw_step:
            break
    start = math.floor(vmin / step) * step
    end = math.ceil(vmax / step) * step
    ticks = []
    x = start
    for _ in range(200):
        if x > end + 1e-12:
            break
        ticks.append(x)
        x += step
    return ticks


def write_svg_2x2(series, plots, output_path):
    width = 1200
    height = 800
    outer_margin = 50
    gap = 40
    ncols = 2
    nrows = 2

    panel_w = (width - 2 * outer_margin - (ncols - 1) * gap) / ncols
    panel_h = (height - 2 * outer_margin - (nrows - 1) * gap) / nrows

    plot_margin_l = 70
    plot_margin_r = 20
    plot_margin_t = 25
    plot_margin_b = 55

    all_times = []
    for s in series:
        all_times.extend(s["time"])
    tmin = min(all_times)
    tmax = max(all_times)
    if tmin == tmax:
        tmin -= 1.0
        tmax += 1.0

    palette = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b"]

    def esc(text):
        return (
            str(text)
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
        )

    def xmap(x, x0, x1, px0, px1):
        return px0 + (x - x0) * (px1 - px0) / (x1 - x0)

    def ymap(y, y0, y1, py0, py1):
        return py1 - (y - y0) * (py1 - py0) / (y1 - y0)

    def polyline(points, color):
        d = " ".join(f"{x:.2f},{y:.2f}" for x, y in points)
        return f'<polyline fill="none" stroke="{color}" stroke-width="2" points="{d}" />'

    def text(x, y, s, size=14, anchor="start", rotate=None):
        rot = ""
        if rotate is not None:
            rot = f' transform="rotate({rotate} {x:.2f} {y:.2f})"'
        return f'<text x="{x:.2f}" y="{y:.2f}" font-size="{size}" text-anchor="{anchor}" font-family="sans-serif"{rot}>{esc(s)}</text>'

    svg = []
    svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">')
    svg.append('<rect x="0" y="0" width="100%" height="100%" fill="white" />')

    time_ticks = _nice_ticks(tmin, tmax, nticks=6)

    for idx, (key, ylabel) in enumerate(plots):
        row = idx // ncols
        col = idx % ncols
        px = outer_margin + col * (panel_w + gap)
        py = outer_margin + row * (panel_h + gap)

        ax_x0 = px + plot_margin_l
        ax_x1 = px + panel_w - plot_margin_r
        ax_y0 = py + plot_margin_t
        ax_y1 = py + panel_h - plot_margin_b

        ymin = None
        ymax = None
        for s in series:
            vals = s.get(key, [])
            if not vals:
                continue
            vmin = min(vals)
            vmax = max(vals)
            ymin = vmin if ymin is None else min(ymin, vmin)
            ymax = vmax if ymax is None else max(ymax, vmax)
        if ymin is None or ymax is None:
            continue
        if ymin == ymax:
            pad = abs(ymin) * 0.05 or 1.0
            ymin -= pad
            ymax += pad

        y_ticks = _nice_ticks(ymin, ymax, nticks=5)

        svg.append(f'<rect x="{px:.2f}" y="{py:.2f}" width="{panel_w:.2f}" height="{panel_h:.2f}" fill="none" stroke="#dddddd" />')
        svg.append(f'<line x1="{ax_x0:.2f}" y1="{ax_y1:.2f}" x2="{ax_x1:.2f}" y2="{ax_y1:.2f}" stroke="black" stroke-width="1" />')
        svg.append(f'<line x1="{ax_x0:.2f}" y1="{ax_y0:.2f}" x2="{ax_x0:.2f}" y2="{ax_y1:.2f}" stroke="black" stroke-width="1" />')

        for tt in time_ticks:
            x = xmap(tt, tmin, tmax, ax_x0, ax_x1)
            svg.append(f'<line x1="{x:.2f}" y1="{ax_y1:.2f}" x2="{x:.2f}" y2="{(ax_y1 + 6):.2f}" stroke="black" />')
            if row == nrows - 1:
                svg.append(text(x, ax_y1 + 22, f"{tt:g}", size=12, anchor="middle"))
            svg.append(f'<line x1="{x:.2f}" y1="{ax_y0:.2f}" x2="{x:.2f}" y2="{ax_y1:.2f}" stroke="#eeeeee" />')

        for yt in y_ticks:
            y = ymap(yt, ymin, ymax, ax_y0, ax_y1)
            svg.append(f'<line x1="{(ax_x0 - 6):.2f}" y1="{y:.2f}" x2="{ax_x0:.2f}" y2="{y:.2f}" stroke="black" />')
            svg.append(text(ax_x0 - 10, y + 4, f"{yt:g}", size=12, anchor="end"))
            svg.append(f'<line x1="{ax_x0:.2f}" y1="{y:.2f}" x2="{ax_x1:.2f}" y2="{y:.2f}" stroke="#eeeeee" />')

        svg.append(text(px + 8, py + 18, ylabel, size=14, anchor="start"))
        if row == nrows - 1:
            svg.append(text((ax_x0 + ax_x1) / 2, py + panel_h - 15, "time", size=14, anchor="middle"))

        legend_x = ax_x0 + 10
        legend_y = ax_y0 + 10
        line_h = 18
        for si, s in enumerate(series):
            color = palette[si % len(palette)]
            svg.append(f'<line x1="{legend_x:.2f}" y1="{legend_y + si * line_h:.2f}" x2="{(legend_x + 24):.2f}" y2="{legend_y + si * line_h:.2f}" stroke="{color}" stroke-width="3" />')
            svg.append(text(legend_x + 30, legend_y + si * line_h + 4, s["label"], size=12, anchor="start"))

        for si, s in enumerate(series):
            color = palette[si % len(palette)]
            t = s["time"]
            yv = s[key]
            n = min(len(t), len(yv))
            pts = []
            for i in range(n):
                pts.append(
                    (
                        xmap(t[i], tmin, tmax, ax_x0, ax_x1),
                        ymap(yv[i], ymin, ymax, ax_y0, ax_y1),
                    )
                )
            if pts:
                svg.append(polyline(pts, color))

    svg.append("</svg>")
    Path(output_path).write_text("\n".join(svg), encoding="utf-8")


def main():
    script_path = Path(__file__).resolve()
    repo_root = script_path.parents[3]

    csv_list = [repo_root / p for p in CSV_PATHS]

    series = []
    for p in csv_list:
        data = load_csv(p)
        if "time" not in data:
            continue
        if not all(key in data for key, _ in PLOTS):
            continue
        series.append(
            {
                "label": p.parent.name or p.stem,
                "time": data["time"],
                **{key: data[key] for key, _ in PLOTS},
            }
        )

    if not series:
        raise RuntimeError("没有找到包含 time 以及目标字段的 CSV")

    output_svg = repo_root / "timeseries_comparison.svg"
    write_svg_2x2(series, PLOTS, output_svg)

    output_paths = [str(output_svg)]
    if plt is not None:
        fig, axes = plt.subplots(nrows=2, ncols=2, figsize=(11, 7), sharex=True)
        axes = axes.reshape(-1)

        for ax, (key, ylabel) in zip(axes, PLOTS, strict=False):
            for s in series:
                ax.plot(s["time"], s[key], label=s["label"])
            ax.set_ylabel(ylabel)
            ax.legend()

        for ax in axes[-2:]:
            ax.set_xlabel("time")

        fig.tight_layout()
        output_png = repo_root / "timeseries_comparison.png"
        fig.savefig(output_png, dpi=200)
        output_paths.append(str(output_png))

        if os.environ.get("DISPLAY"):
            plt.show()

    print("\n".join(output_paths))


if __name__ == "__main__":
    main()
