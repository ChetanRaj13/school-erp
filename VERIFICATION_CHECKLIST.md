# Admin Workspace Split & Feature Verification Checklist

Open this file in your IDE to check off items as you verify http://localhost:8080.

---

## 1. Admin Workspace Toggle & Shared Operations
- [Done but email is anita@gmail.com] Sign in as Admin (`admin@school.edu` / `abcd@1234`).
- [Yes confirmed] Confirm the workspace toggle at the top of the Admin sidebar with **HR** and **Finance** segments.
- [ YES confirmed ] Confirm the shared **Operations** section is present and always visible in both workspaces:
  - [Yes confirmed ] **Announcements** (`/admin/announcements`)
  - [ Yes confirmed ] **Messages** (`/admin/messages`)
  - [ Yes confirmed ] **OMR Attendance** (`/admin/omr`)
  - [Yes confirmed ] **Document Review** (`/admin/documents`)
  - [Yes confirmed ] **Weekly Timetable** (`/admin/timetable`)

---

## 2. HR Workspace
- [ DONE ] Click **HR** on the workspace toggle.
- [ No its not switching automatically ] Confirm the main view switches to **HR Overview**:
  - [ Yes its there ] Staff headcount by role (Total staff & breakdown)
  - [ Yes its there ] Leave request summary (Pending, Approved this month, Rejected this month)
  - [ Yes its there ] Payroll summary (Pending approval & Paid this month)
  - [ No its not there : "Not yet in use" -staff_attendece table existes but has no rows. This is visible to me with one more line ] Staff Attendance honest gap banner (*"Not yet in use"* — zero fabricated percentages)
- [ Yes its there ] Confirm the sidebar displays HR-specific sections:
  - [ Yes its there ] **Payroll** (`/admin/payroll`)
  - [ Yes its there ] **HR Approvals** (`/admin/approvals/hr` — filtered to payroll runs only)
  - [ Yes its there ] **Leave Requests** (`/admin/leave`)

---

## 3. Finance Workspace
- [ Done ] Click **Finance** on the workspace toggle.
- [ No its not switching ] Confirm the main view switches to **Finance Overview**:
  - [ Yes its there ] Fee collection breakdown (Collected / Pending / Overdue)
  - [ Yes its there ] Revenue vs Expense vs Budget summary
  - [ Yes its there ] Purchase-order pipeline by status
  - [ Yes its there ] EMI plans active count
  - [ Yes its there ] Pending waivers count
- [ Yes its there ] Confirm the sidebar displays Finance-specific sections:
  - [ Yes its there ] **Vendors & Procurement** (`/admin/vendors`)
  - [ Yes its there ] **Finance Approvals** (`/admin/approvals/finance` — POs and vendor payments only)
  - [ Yes its there ] **EMI / Fee Financing** (`/admin/emi`)
  - [ Yes its there ] **Late Fees** (`/admin/late-fees`)
  - [ Yes its there ] **Scholarships & Waivers** (`/admin/waivers`)
  - [ Yes its there ] **Budget** (`/admin/budget`)
  - [ Yes its there ] **Bank Reconciliation** (`/admin/bank-reconciliation`)
  - [ Yes its there ] **Fee Management** (`/admin/fees`)
  - [ Yes its there ] **Offline Payment Entry** (`/admin/offline-payments`)
  - [ Yes its there ] **Recent Payments** (`/admin/recent-payments` — distinct screen from overview)

---

## 4. Waiver Disbursement Flow
- [ Done ] Navigate to **Scholarships & Waivers** (`/admin/waivers`).
- [ I found the disbursement is not done request ] Locate an approved request where `disbursed_at` is null.
- [ Yes ] Confirm the green **Disburse** button is visible.
- [ Yes ] Click **Disburse**, review the confirmation dialog, and click **Disburse**.
- [ Yes ] Verify `disbursed_at` is set (showing green *"Disbursed"* chip) and invoice `amount_due` is reduced.

Additional comment: If the disbursement amount is more than the outstanding balance then I am able to pay only the outstanding balance amount, which if fine and correct but once I click on disburse. it says disburse, the extra amount which was left, I am not able to do anything with that. Second I am not able to seach anything on the searchbar on the top. And this issue of searchbar is happening everywhere.

---

## 5. GST Invoice Generation
- [ Done ] Navigate to **Fee Management** (`/admin/fees`).
- [ Yes ] Find an invoice in the **Overdue** or **Upcoming** tab.
- [ Its sAYING - PDF Signed URL:
https://yhcyhwpdgqupylrnkqht.supabase.co/storage/v1/object/sign/receipts/tax-invoice-f8ac9e85-54af-4ada-9260-3e1971b94a69.pdf?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV8yYTEwZmY3Zi02NjQ3LTRkNDgtODU5YS0wYWFiYjM4NDE3YTEiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJyZWNlaXB0cy90YXgtaW52b2ljZS1mOGFjOWU4NS01NGFmLTRhZGEtOTI2MC0zZTE5NzFiOTRhNjkucGRmIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc4NjI2NzU2MCwiZXhwIjoxNzg2MjcxMTYwfQ.hKCqtkLr51n2Oh3Z4_dkgpwApcgd7J98LJRa5bjKN8w - SO it created a gst invoice but its not opening the gst invoice but just giving the link] Click the **GST Invoice** button on the invoice card.
- [ Yes ] Confirm the GST Tax Invoice PDF is generated and uploaded, and a modal dialog displays the signed PDF URL.
