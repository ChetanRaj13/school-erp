import urllib.request, json

boundary = "----BoundaryOmrTest"

def encode_file(name, filepath, field_name):
    with open(filepath, "rb") as f:
        data = f.read()
    ct = "image/jpeg" if filepath.endswith(".jpg") else "application/json"
    return (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"{field_name}\"; "
        f"filename=\"{name}\"\r\nContent-Type: {ct}\r\n\r\n"
    ).encode() + data + b"\r\n"

def encode_field(name, value):
    return (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n"
    ).encode()

body = (
    encode_file("simulated_phone_photo.jpg", "sample_output/simulated_phone_photo.jpg", "image") +
    encode_file("class_8A_template.json",    "sample_output/class_8A_template.json", "template") +
    encode_field("class_id", "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa") +
    encode_field("date", "2026-07-22") +
    f"--{boundary}--\r\n".encode()
)

req = urllib.request.Request(
    "http://localhost:8002/scan",
    data=body,
    headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    method="POST",
)

try:
    r = urllib.request.urlopen(req, timeout=60)
    data = json.loads(r.read().decode())
    print("=== SUMMARY ===")
    print(json.dumps(data["summary"], indent=2))
    print(f"Inserted: {data['inserted']} rows")
    print(f"Date: {data['attendance_date']}")
    print("\n=== FIRST 5 RECORDS ===")
    for rec in data["records"][:5]:
        name = rec["student_name"] or "(no roster match)"
        print(f"  Roll {rec['roll_no']:2d}: {name:<20s}  status={rec['status']}  conf={rec['confidence']}  review={rec['needs_review']}")
    print("\n=== FULL JSON ===")
    print(json.dumps(data, indent=2)[:2000])
except urllib.error.HTTPError as e:
    print(f"HTTP {e.code}: {e.read().decode()}")
except Exception as e:
    print(f"Error: {e}")
