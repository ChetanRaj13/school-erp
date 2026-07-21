"""
test_pipeline.py — sanity test, not part of the production app.
Takes the rendered blank sheet, programmatically fills in bubbles for a known
ground-truth attendance pattern, warps/rotates/adds noise to simulate a phone
photo, then runs scan_omr.py against it and checks the recovered results
match the ground truth.
"""
import json
import random

import cv2
import numpy as np

RENDER_PNG = "output/class_8A_render-1.png"
TEMPLATE_JSON = "output/class_8A_template.json"
RENDER_DPI = 200
PT_TO_PX = RENDER_DPI / 72.0  # points -> pixels at render resolution

random.seed(42)


def fill_bubbles_ground_truth(template):
    img = cv2.imread(RENDER_PNG)
    h_img = img.shape[0]

    by_roll = {}
    for b in template["bubbles"]:
        by_roll.setdefault(b["roll_no"], {})[b["option"]] = b

    ground_truth = {}
    for roll_no, opts in by_roll.items():
        # simulate ~85% present, 15% absent
        status = "present" if random.random() < 0.85 else "absent"
        ground_truth[roll_no] = status
        bubble = opts["P"] if status == "present" else opts["A"]

        cx = bubble["x_pt"] * PT_TO_PX
        cy = h_img - (bubble["y_pt"] * PT_TO_PX)
        r = int(template["bubble_radius_pt"] * PT_TO_PX * 0.75)
        cv2.circle(img, (int(cx), int(cy)), r, (20, 20, 20), thickness=-1)

    cv2.imwrite("output/filled_sheet.png", img)
    with open("output/ground_truth.json", "w") as f:
        json.dump(ground_truth, f, indent=2)
    return img, ground_truth


def simulate_phone_photo(img):
    h, w = img.shape[:2]
    # random mild perspective warp (simulating a hand-held photo, not dead-on)
    margin = 0.03
    src = np.float32([[0, 0], [w, 0], [w, h], [0, h]])
    dst = np.float32([
        [random.uniform(0, margin) * w, random.uniform(0, margin) * h],
        [w - random.uniform(0, margin) * w, random.uniform(0, margin) * h],
        [w - random.uniform(0, margin) * w, h - random.uniform(0, margin) * h],
        [random.uniform(0, margin) * w, h - random.uniform(0, margin) * h],
    ])
    M = cv2.getPerspectiveTransform(src, dst)
    warped = cv2.warpPerspective(img, M, (w, h), borderValue=(230, 230, 230))

    # slight rotation
    angle = random.uniform(-2, 2)
    center = (w // 2, h // 2)
    rot_mat = cv2.getRotationMatrix2D(center, angle, 1.0)
    rotated = cv2.warpAffine(warped, rot_mat, (w, h), borderValue=(230, 230, 230))

    # brightness / noise to mimic phone camera + ambient lighting
    noise = np.random.normal(0, 6, rotated.shape).astype(np.int16)
    noisy = np.clip(rotated.astype(np.int16) + noise, 0, 255).astype(np.uint8)
    bright = cv2.convertScaleAbs(noisy, alpha=1.03, beta=6)

    cv2.imwrite("output/simulated_phone_photo.jpg", bright, [cv2.IMWRITE_JPEG_QUALITY, 88])
    return "output/simulated_phone_photo.jpg"


def main():
    with open(TEMPLATE_JSON) as f:
        template = json.load(f)

    img, ground_truth = fill_bubbles_ground_truth(template)
    photo_path = simulate_phone_photo(img)
    print(f"Simulated phone photo saved: {photo_path}")

    import scan_omr
    result = scan_omr.scan(photo_path, TEMPLATE_JSON, "output/scan_result.json")

    correct, wrong, review = 0, 0, 0
    for r in result["results"]:
        gt = ground_truth[str(r["roll_no"])] if str(r["roll_no"]) in ground_truth else ground_truth[r["roll_no"]]
        if r["needs_review"]:
            review += 1
        elif r["status"] == gt:
            correct += 1
        else:
            wrong += 1
            print(f"  MISMATCH roll {r['roll_no']}: predicted={r['status']} actual={gt}")

    total = len(result["results"])
    print(f"\nTotal rolls: {total}")
    print(f"Correct:     {correct}")
    print(f"Wrong:       {wrong}")
    print(f"Needs review:{review}")
    print(f"Accuracy (excluding flagged-for-review): {correct/(correct+wrong)*100:.1f}%" if (correct+wrong) else "N/A")


if __name__ == "__main__":
    main()
