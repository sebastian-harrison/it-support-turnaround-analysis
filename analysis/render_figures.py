"""Draw the README figures from the prepared case data."""

import csv
from functools import lru_cache
import os
from pathlib import Path
import statistics

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
INK = "#19354a"
BLUE = "#306b89"
GREY = "#9babb5"
LIGHT = "#e7edf1"
ORANGE = "#a66b38"
MUTED = "#526575"
SCALE = 3
WIDTH, HEIGHT = 1100, 410


@lru_cache(maxsize=None)
def font(size, bold=False):
    directories = [
        Path("/System/Library/Fonts/Supplemental"),
        Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts",
        Path("/usr/share/fonts/truetype/msttcorefonts"),
        Path("/usr/share/fonts/truetype/dejavu"),
    ]
    names = (["Arial Bold.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf"] if bold
             else ["Arial.ttf", "arial.ttf", "DejaVuSans.ttf"])
    for directory in directories:
        for name in names:
            if (directory / name).is_file():
                return ImageFont.truetype(str(directory / name), int(size * SCALE))
    return ImageFont.load_default(size=int(size * SCALE))


class Figure:
    def __init__(self, title, subtitle):
        self.image = Image.new("RGB", (WIDTH * SCALE, HEIGHT * SCALE), "white")
        self.draw = ImageDraw.Draw(self.image)
        self.text(32, 38, title, size=23, bold=True)
        self.text(32, 70, subtitle, size=16, color=MUTED)

    def text(self, x, y, value, size=17, color=INK, align="left", bold=False):
        anchor = {"left": "ls", "center": "ms", "right": "rs"}[align]
        self.draw.text((x * SCALE, y * SCALE), str(value), font=font(size, bold),
                       fill=color, anchor=anchor)

    def line(self, x1, y1, x2, y2):
        self.draw.line((x1 * SCALE, y1 * SCALE, x2 * SCALE, y2 * SCALE),
                       fill=LIGHT, width=SCALE)

    def bar(self, x, y, width, color):
        self.draw.rectangle((x * SCALE, (y - 14) * SCALE,
                             (x + width) * SCALE, (y + 14) * SCALE), fill=color)

    def dot(self, x, y, color):
        radius = 3.5
        self.draw.ellipse(((x - radius) * SCALE, (y - radius) * SCALE,
                           (x + radius) * SCALE, (y + radius) * SCALE), fill=color)

    def save(self, filename):
        destination = ROOT / "images"
        destination.mkdir(exist_ok=True)
        self.image.resize((WIDTH * 2, HEIGHT * 2), Image.Resampling.LANCZOS).save(
            destination / filename)


def reassignment_figure(cases):
    figure = Figure("Resolution times increase with reassignments",
                    "Median resolution time (days)")
    figure.text(1060, 112, "Cases", size=14, color=MUTED, align="right")
    for tick in range(0, 11, 2):
        x = 240 + 54 * tick
        figure.line(x, 128, x, 359)
        figure.text(x, 385, tick, size=14, color=MUTED, align="center")

    groups = [
        ("0", "No reassignment", GREY),
        ("1", "1 reassignment", BLUE),
        ("2", "2 reassignments", BLUE),
        ("3+", "3 or more", INK),
    ]
    for index, (group, label, color) in enumerate(groups):
        rows = [case for case in cases if case["reassignment_band"] == group]
        duration = statistics.median(float(case["resolution_days"]) for case in rows
                                     if case["resolution_eligible"] == "1")
        y = 155 + index * 59
        figure.text(32, y + 6, label)
        figure.bar(240, y, duration * 54, color)
        if index == 0:
            figure.dot(240 + duration * 54, y, color)
        value = "Under 1 hour" if duration < 1 / 24 else f"{duration:.1f}"
        figure.text(250 + duration * 54, y + 6, value, bold=True)
        figure.text(1060, y + 6, f"{len(rows):,}", align="right")
    figure.save("resolution_by_reassignment.png")


def category_figure(cases):
    figure = Figure("Categories 46 and 34 account for 30% of slow cases",
                    "Slow-case counts and rates, compared with Category 42")
    figure.text(930, 112, "Cases", size=14, color=MUTED, align="right")
    figure.text(1060, 112, "Slow cases (%)", size=14, color=MUTED, align="right")
    for tick in range(0, 501, 100):
        x = 240 + 1.06 * tick
        figure.line(x, 128, x, 305)
        figure.text(x, 334, tick, size=14, color=MUTED, align="center")

    for index, (category, color) in enumerate([
        ("Category 46", BLUE), ("Category 34", ORANGE), ("Category 42", GREY),
    ]):
        rows = [case for case in cases if case["first_category"] == category]
        eligible = sum(case["resolution_eligible"] == "1" for case in rows)
        slow = sum(case["slow_resolution_flag"] == "1" for case in rows)
        y = 155 + index * 65
        figure.text(32, y + 6, category)
        figure.bar(240, y, slow * 1.06, color)
        figure.text(250 + slow * 1.06, y + 6, f"{slow:,}", bold=True)
        figure.text(930, y + 6, f"{eligible:,}", align="right")
        figure.text(1060, y + 6, f"{slow / eligible:.0%}", align="right", bold=index == 1)

    figure.text(505, 361, "Number of slow cases", size=14, color=MUTED, align="center")
    figure.text(32, 395, "Slow cases take about 16 days or more to resolve.",
                size=14, color=MUTED)
    figure.save("slow_case_concentration.png")


def main():
    with (ROOT / "data/tableau/cases.csv").open(newline="", encoding="utf-8") as source:
        cases = list(csv.DictReader(source))
    reassignment_figure(cases)
    category_figure(cases)
    print("Saved the reassignment and category figures in images/.")


if __name__ == "__main__":
    main()
