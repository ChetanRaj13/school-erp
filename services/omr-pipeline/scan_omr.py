"""
scan_omr.py
Takes a photographed/scanned OMR attendance sheet + its template.json,
corrects perspective using the 4 ArUco corner markers, then reads each
bubble's fill level to determine Present/Absent per roll number.

Usage:
    python3 scan_omr.py --image path/to/photo.jpg --template output/class_8A_template.json --out output/result.json

Output JSON shape:
{
  "class_name": "8-A",
  "date": "2026-07-19",
  "results": [
     {"roll_no": 1, "status": "present", "confidence": 0.93, "needs_review": false},
     {"roll_no": 2, "status": "absent",  "confidence": 0.88, "needs_review": false},
     {"roll_no": 3, "status": null,      "confidence": 0.10, "needs_review": true}   # both/neither bubble filled
  ]
}
"""

import argparse
import json

import cv2
import numpy as np

ARUCO_DICT = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50)
ARUCO_PARAMS = cv2.aruco.DetectorParameters()
DETECTOR = cv2.aruco.ArucoDetector(ARUCO_DICT, ARUCO_PARAMS)

# Canonical warped-image resolution: 2 pixels per PDF point gives a sharp,
# consistent working image regardless of the original photo's resolution.
PX_PER_PT = 2.0

FILL_THRESHOLD = 0.35          # fraction of dark pixels inside a bubble to call it "filled"
AMBIGUOUS_MARGIN = 0.12        # if both bubbles' fill fractions are this close, flag for review


def load_template(path):
    with open(path) as f:
        return json.load(f)


def find_markers(gray_img):
    corners, ids, _ = DETECTOR.detectMarkers(gray_img)
    if ids is None or len(ids) < 4:
        raise RuntimeError(
            f"Could not detect all 4 corner markers (found {0 if ids is None else len(ids)}). "
            "Retake the photo with all four corners visible and good lighting."
        )
    id_to_center = {}
    for corner_set, marker_id in zip(corners, ids.flatten()):
        pts = corner_set[0]
        center = pts.mean(axis=0)
        id_to_center[int(marker_id)] = center
    required = {0, 1, 2, 3}
    missing = required - set(id_to_center.keys())
    if missing:
        raise RuntimeError(f"Missing corner marker id(s): {missing}. Retake the photo.")
    return id_to_center  # {0: TL, 1: TR, 2: BR, 3: BL}


def warp_to_canonical(img, marker_centers, template):
    page_w_px = int(template["page_width_pt"] * PX_PER_PT)
    page_h_px = int(template["page_height_pt"] * PX_PER_PT)

    # Marker centers in the source photo, ordered TL, TR, BR, BL
    src_pts = np.array([
        marker_centers[0],
        marker_centers[1],
        marker_centers[2],
        marker_centers[3],
    ], dtype=np.float32)

    # Where those same marker centers SHOULD be in the canonical (warped) image,
    # derived from how generate_omr.py placed them (in PDF points -> flip Y for image coords).
    m = template["marker_margin_pt"]
    s = template["marker_size_pt"]
    half = s / 2.0

    def pt_to_px(x_pt, y_pt_from_bottom):
        x_px = x_pt * PX_PER_PT
        y_px = (template["page_height_pt"] - y_pt_from_bottom) * PX_PER_PT
        return x_px, y_px

    dst_pts = np.array([
        pt_to_px(m + half, template["page_height_pt"] - m - half),  # TL marker center
        pt_to_px(template["page_width_pt"] - m - half, template["page_height_pt"] - m - half),  # TR
        pt_to_px(template["page_width_pt"] - m - half, m + half),   # BR
        pt_to_px(m + half, m + half),                                 # BL
    ], dtype=np.float32)

    H = cv2.getPerspectiveTransform(src_pts, dst_pts)
    warped = cv2.warpPerspective(img, H, (page_w_px, page_h_px))
    return warped


def bubble_fill_fraction(gray_warped, x_pt, y_pt, radius_pt, page_h_pt):
    cx = x_pt * PX_PER_PT
    cy = (page_h_pt - y_pt) * PX_PER_PT
    r = int(radius_pt * PX_PER_PT * 0.8)  # sample slightly inside the printed circle

    h, w = gray_warped.shape
    x0, x1 = max(0, int(cx - r)), min(w, int(cx + r))
    y0, y1 = max(0, int(cy - r)), min(h, int(cy + r))
    if x1 <= x0 or y1 <= y0:
        return 0.0

    roi = gray_warped[y0:y1, x0:x1]
    _, thresh = cv2.threshold(roi, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    dark_fraction = np.count_nonzero(thresh) / thresh.size
    return float(dark_fraction)


def scan(image_path, template_path, out_path):
    template = load_template(template_path)
    img = cv2.imread(image_path)
    if img is None:
        raise RuntimeError(f"Could not read image: {image_path}")

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    marker_centers = find_markers(gray)
    warped = warp_to_canonical(img, marker_centers, template)
    warped_gray = cv2.cvtColor(warped, cv2.COLOR_BGR2GRAY) if warped.ndim == 3 else warped

    # group bubbles by roll_no
    by_roll = {}
    for b in template["bubbles"]:
        by_roll.setdefault(b["roll_no"], {})[b["option"]] = b

    results = []
    page_h_pt = template["page_height_pt"]
    for roll_no, opts in sorted(by_roll.items()):
        p_bubble = opts.get("P")
        a_bubble = opts.get("A")
        p_fill = bubble_fill_fraction(warped_gray, p_bubble["x_pt"], p_bubble["y_pt"],
                                       template["bubble_radius_pt"], page_h_pt)
        a_fill = bubble_fill_fraction(warped_gray, a_bubble["x_pt"], a_bubble["y_pt"],
                                       template["bubble_radius_pt"], page_h_pt)

        p_filled = p_fill >= FILL_THRESHOLD
        a_filled = a_fill >= FILL_THRESHOLD

        needs_review = False
        status = None
        confidence = max(p_fill, a_fill)

        if p_filled and not a_filled:
            status = "present"
        elif a_filled and not p_filled:
            status = "absent"
        elif p_filled and a_filled:
            needs_review = True  # both marked
        else:
            needs_review = True  # neither marked

        if abs(p_fill - a_fill) < AMBIGUOUS_MARGIN and (p_filled or a_filled):
            needs_review = True

        results.append({
            "roll_no": roll_no,
            "status": status,
            "confidence": round(confidence, 2),
            "needs_review": needs_review,
        })

    output = {
        "class_name": template.get("class_name"),
        "date": template.get("date"),
        "results": results,
    }
    with open(out_path, "w") as f:
        json.dump(output, f, indent=2)

    # also save the warped/debug image so it's easy to eyeball what got detected
    debug_path = out_path.replace(".json", "_warped.png")
    cv2.imwrite(debug_path, warped)

    print(f"Results written to: {out_path}")
    print(f"Debug warped image: {debug_path}")
    return output


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", required=True)
    ap.add_argument("--template", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    scan(args.image, args.template, args.out)
