"""
generate_omr.py
Generates a printable class-attendance OMR sheet (PDF) plus a template.json
describing the exact coordinate of every bubble, and the 4 ArUco corner
markers used later for perspective correction when scanning.

Usage:
    python3 generate_omr.py --class "8-A" --date "2026-07-19" \
        --roll-start 1 --roll-end 40 --out output/class_8A

Produces:
    output/class_8A.pdf         -> print this and hand to the teacher
    output/class_8A_template.json -> used by scan_omr.py, keep it with the code
"""

import argparse
import json
import os

import cv2
import numpy as np
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm

PAGE_W, PAGE_H = A4  # points, 595.27 x 841.89 for A4

ARUCO_DICT = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50)
MARKER_SIZE_PT = 34  # printed marker size in points (~12mm)
MARKER_MARGIN = 18   # distance from page edge, in points

BUBBLE_RADIUS = 5.2  # points
ROW_HEIGHT = 16.5    # points
COL_GAP = 70         # points between the two "column blocks" of the sheet
ROWS_PER_COL = 25     # max rows before starting a second column block

TOP_MARGIN_FOR_ROWS = 165  # points from top of page where the roll grid starts


def make_marker_png(marker_id: int, path: str, px: int = 300):
    img = cv2.aruco.generateImageMarker(ARUCO_DICT, marker_id, px)
    cv2.imwrite(path, img)


def build(class_name, section_date, roll_start, roll_end, out_prefix):
    os.makedirs(os.path.dirname(out_prefix) or ".", exist_ok=True)
    tmp_dir = out_prefix + "_markers"
    os.makedirs(tmp_dir, exist_ok=True)

    marker_paths = {}
    for mid in [0, 1, 2, 3]:
        p = os.path.join(tmp_dir, f"marker_{mid}.png")
        make_marker_png(mid, p)
        marker_paths[mid] = p

    pdf_path = out_prefix + ".pdf"
    c = canvas.Canvas(pdf_path, pagesize=A4)

    # ---- 4 ArUco corner markers: 0=TL, 1=TR, 2=BR, 3=BL ----
    corners_pt = {
        0: (MARKER_MARGIN, PAGE_H - MARKER_MARGIN - MARKER_SIZE_PT),                         # top-left
        1: (PAGE_W - MARKER_MARGIN - MARKER_SIZE_PT, PAGE_H - MARKER_MARGIN - MARKER_SIZE_PT),  # top-right
        2: (PAGE_W - MARKER_MARGIN - MARKER_SIZE_PT, MARKER_MARGIN),                          # bottom-right
        3: (MARKER_MARGIN, MARKER_MARGIN),                                                     # bottom-left
    }
    for mid, (x, y) in corners_pt.items():
        c.drawImage(marker_paths[mid], x, y, MARKER_SIZE_PT, MARKER_SIZE_PT)

    # ---- Header ----
    c.setFont("Helvetica-Bold", 16)
    c.drawCentredString(PAGE_W / 2, PAGE_H - 70, "CLASS ATTENDANCE SHEET")
    c.setFont("Helvetica", 11)
    c.drawString(70, PAGE_H - 95, f"Class / Section: {class_name}")
    c.drawString(70, PAGE_H - 112, f"Date: {section_date}")
    c.drawString(PAGE_W - 200, PAGE_H - 95, "Marked by: ______________")
    c.setFont("Helvetica", 8)
    c.drawCentredString(PAGE_W / 2, PAGE_H - 132,
                         "Fill the bubble completely using a dark pen.   P = Present    A = Absent")

    # ---- Roll grid ----
    template = {
        "class_name": class_name,
        "date": section_date,
        "page_width_pt": PAGE_W,
        "page_height_pt": PAGE_H,
        "aruco_dict": "DICT_4X4_50",
        "marker_ids": {"top_left": 0, "top_right": 1, "bottom_right": 2, "bottom_left": 3},
        "marker_size_pt": MARKER_SIZE_PT,
        "marker_margin_pt": MARKER_MARGIN,
        "bubble_radius_pt": BUBBLE_RADIUS,
        "bubbles": []  # list of {roll_no, option, x_pt, y_pt}
    }

    rolls = list(range(roll_start, roll_end + 1))
    col_block_x = [90, 90 + COL_GAP + 170]  # two block start-x positions
    start_y = PAGE_H - TOP_MARGIN_FOR_ROWS

    c.setFont("Helvetica-Bold", 9)
    for block_idx, block_x in enumerate(col_block_x):
        c.drawString(block_x, start_y + 14, "Roll")
        c.drawString(block_x + 60, start_y + 14, "P")
        c.drawString(block_x + 90, start_y + 14, "A")

    c.setFont("Helvetica", 9)
    for i, roll in enumerate(rolls):
        block_idx = i // ROWS_PER_COL
        row_in_block = i % ROWS_PER_COL
        if block_idx >= len(col_block_x):
            break  # sheet full; generate a second page in real use if needed
        x0 = col_block_x[block_idx]
        y = start_y - row_in_block * ROW_HEIGHT

        c.drawString(x0, y - 3, str(roll))

        p_x, p_y = x0 + 63, y
        a_x, a_y = x0 + 93, y

        c.circle(p_x, p_y, BUBBLE_RADIUS, stroke=1, fill=0)
        c.circle(a_x, a_y, BUBBLE_RADIUS, stroke=1, fill=0)

        template["bubbles"].append({"roll_no": roll, "option": "P", "x_pt": p_x, "y_pt": p_y})
        template["bubbles"].append({"roll_no": roll, "option": "A", "x_pt": a_x, "y_pt": a_y})

    c.showPage()
    c.save()

    template_path = out_prefix + "_template.json"
    with open(template_path, "w") as f:
        json.dump(template, f, indent=2)

    print(f"PDF written to:      {pdf_path}")
    print(f"Template written to: {template_path}")
    return pdf_path, template_path


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--class", dest="class_name", required=True)
    ap.add_argument("--date", dest="date", required=True)
    ap.add_argument("--roll-start", type=int, default=1)
    ap.add_argument("--roll-end", type=int, default=40)
    ap.add_argument("--out", dest="out_prefix", required=True)
    args = ap.parse_args()
    build(args.class_name, args.date, args.roll_start, args.roll_end, args.out_prefix)
