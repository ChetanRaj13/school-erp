"""Runtime verification of setState Future fix across affected screens."""
from playwright.sync_api import sync_playwright
import time, os

SCREENSHOTS = os.path.join(os.path.dirname(__file__), "verify_screenshots")
os.makedirs(SCREENSHOTS, exist_ok=True)

def screenshot(page, name):
    path = os.path.join(SCREENSHOTS, f"{name}.png")
    page.screenshot(path=path, full_page=True)
    print(f"  OK {name}")

def wait_and_check_errors(page, timeout_ms=5000):
    """Check console for setState Future errors."""
    errors = []
    page.on("console", lambda msg: errors.append(msg.text) if msg.type == "error" else None)
    page.wait_for_timeout(timeout_ms)
    future_errors = [e for e in errors if "Future" in e or "setState" in e]
    return future_errors

def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(viewport={"width": 1400, "height": 900})

        # Collect ALL console errors
        all_errors = []

        page = context.new_page()
        page.on("console", lambda msg: all_errors.append(msg.text) if msg.type == "error" else None)

        print("1. Loading app...")
        page.goto("http://localhost:8080", wait_until="networkidle", timeout=30000)
        page.wait_for_timeout(3000)
        screenshot(page, "01_splash")

        print("2. Login screen...")
        # Wait for login screen to appear
        try:
            page.wait_for_selector("input", timeout=10000)
            screenshot(page, "02_login")
        except:
            print("  (no input found, taking screenshot anyway)")
            screenshot(page, "02_login")

        print("3. Entering credentials...")
        inputs = page.query_selector_all("input")
        if len(inputs) >= 2:
            inputs[0].fill("admin@school.com")
            inputs[1].fill("password123")
            screenshot(page, "03_filled")
            # Find and click login button
            buttons = page.query_selector_all("button")
            for btn in buttons:
                if btn.text_content() and "log" in btn.text_content().lower():
                    btn.click()
                    break
            else:
                if buttons:
                    buttons[-1].click()
            page.wait_for_timeout(3000)
            screenshot(page, "04_after_login")

        print("4. Checking for console errors...")
        # Check all collected errors
        future_errors = [e for e in all_errors if "Future" in e or "setState" in e]
        if future_errors:
            print(f"  FAIL FOUND setState/Future ERRORS: {future_errors}")
        else:
            print("  OK No setState/Future errors in console")

        # Try navigating to various screens
        print("5. Navigating to dashboard screens...")
        nav_items = page.query_selector_all("[role='button'], [class*='nav'], [class*='drawer'], [class*='menu'], [class*='list']")

        # Try to find and click navigation items
        test_screens = [
            "Announcements", "Messages", "Leave", "Assignments",
            "Payroll", "Budget", "Late", "Approval", "Vendor",
            "Waiver", "EMI"
        ]

        for screen_name in test_screens:
            try:
                links = page.query_selector_all(f"text=/{screen_name}/i")
                if links:
                    links[0].click()
                    page.wait_for_timeout(2000)
                    screenshot(page, f"05_{screen_name.lower().replace(' ', '_')}")
                    print(f"  OK Navigated to {screen_name}")
            except Exception as e:
                pass  # Screen might not be visible for this role

        # Final error check
        print("\n6. Final error summary:")
        future_errors = [e for e in all_errors if "Future" in e or "setState" in e]
        if future_errors:
            print(f"  FAIL {len(future_errors)} setState/Future errors found:")
            for e in future_errors:
                print(f"    - {e}")
        else:
            print("  OK ZERO setState/Future errors across entire session")

        if all_errors:
            print(f"\n  All errors ({len(all_errors)}):")
            for e in all_errors[:10]:
                print(f"    - {e[:200]}")

        browser.close()
        print("\nDone! Screenshots saved to verify_screenshots/")

if __name__ == "__main__":
    main()
