# OMR Pipeline — already built & validated (100% accuracy on simulated phone-photo test)

- `generate_omr.py` — prints an attendance sheet with ArUco corner markers + template.json
- `scan_omr.py` — perspective-corrects a scanned/photographed sheet and reads bubble fills
- `test_pipeline.py` — end-to-end sanity test with a simulated warped/rotated/noisy photo

Next step: wrap `scan_omr.scan()` in a FastAPI endpoint (`main.py`, not yet created)
that accepts an uploaded image and writes results into `attendance.records`
(`method: 'omr'`) via the Supabase service-role client.

## sample_output/
Proof-of-concept files from the original validation run — useful for demos
and judges, not meant to be regenerated on every run:
- `class_8A.pdf` — a real generated attendance sheet (Class 8-A, 40 rolls)
- `class_8A_template.json` — its matching bubble-coordinate template
- `simulated_phone_photo.jpg` — that sheet, filled in, with simulated perspective warp/rotation/camera noise (mimics a hand-held phone photo)
- `scan_result.json` — scan_omr.py's output on that photo (40/40 correct against ground truth)
