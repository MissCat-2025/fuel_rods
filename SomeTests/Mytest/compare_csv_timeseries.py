import csv
from pathlib import Path

import matplotlib.pyplot as plt


CSV_PATHS = [
    "fuel_rods/SomeTests/Mytest/PlaneStress/PlaneStressCeramic_post.csv",
    "fuel_rods/SomeTests/Mytest/PaneStrain/PaneStrainCeramic_physics_post.csv",
    "fuel_rods/SomeTests/Mytest/3D/3DPressure.csv",
    "fuel_rods/SomeTests/Mytest/GeneralizedPaneStrain/PaneStrainCeramic_physics_post.csv"
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


def main():
    script_path = Path(__file__).resolve()
    repo_root = script_path.parents[3]

    csv_list = [repo_root / p for p in CSV_PATHS]

    series = []
    for p in csv_list:
        data = load_csv(p)
        if "time" not in data:
            continue
        if "avg_temp" not in data or "max_MaxPrincipal" not in data:
            continue
        series.append(
            {
                "label": p.stem,
                "time": data["time"],
                "avg_temp": data["avg_temp"],
                "max_MaxPrincipal": data["max_MaxPrincipal"],
            }
        )

    if not series:
        raise RuntimeError("没有找到包含 time/avg_temp/max_MaxPrincipal 的 CSV")

    fig, axes = plt.subplots(nrows=2, ncols=1, figsize=(8, 6), sharex=True)

    ax_temp = axes[0]
    ax_stress = axes[1]

    for s in series:
        ax_temp.plot(s["time"], s["avg_temp"], label=s["label"])
    ax_temp.set_ylabel("avg_temp")
    ax_temp.legend()

    for s in series:
        ax_stress.plot(s["time"], s["max_MaxPrincipal"], label=s["label"])
    ax_stress.set_xlabel("time")
    ax_stress.set_ylabel("max_MaxPrincipal")
    ax_stress.legend()

    fig.tight_layout()
    plt.show()


if __name__ == "__main__":
    main()
