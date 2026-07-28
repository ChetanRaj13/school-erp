# Budget Dashboard Redesign Plan — Principal View
**Version:** 1.0
**Date:** 2026-07-28
**Purpose:** Comprehensive redesign of the budget management interface to reflect real-world school finance operations and provide actionable insights for Principals.

---

## Executive Summary

The current Budget screen only shows planned vs actual spend per category via simple progress rings—a view that is too superficial for effective school financial governance. A school Principal needs a dashboard that supports strategic planning, resource allocation, compliance oversight, and real-time monitoring of fiscal health across all finance domains. This plan outlines an information architecture, KPIs, charts, tables, quick actions, drill-down pathways, and data sources tailored specifically to the Principal's responsibilities.

---

## 1. Information Architecture

### 1.1 Navigation Context

```
Principal Dashboard (Home)
├── Financial Overview ← New Budget Dashboard Entry Point
│   └── Budget Planning & Monitoring
├── Fee Management
├── Vendor & Procurement
├── Payroll Oversight
├── Scholarship & Waiver Review
└── Reports & Exports
```

### 1.2 Hierarchy of Financial Awareness

| Tier | Name | Time Horizon | Purpose |
|------|------|-------------|---------|
| **Level 1** | Instant Health Now (current day/week) | Real-time | Spot immediate issues, validate daily cash flow |
| **Level 2** | Short-Term Trend Past Quarter | Rolling 3 months | Identify patterns, catch overspending early |
| **Level 3** | Mid-Year Status Half Academic Year | Semester checkpoints | Compare progress against budget, adjust allocations |
| **Level 4** | Full-Academic Review End-of-Year | Annual cycle | Audit, compliance, prepare next year's budget |

### 1.3 Dashboard Sections

**Section A: Executive Financial Summary (Above the Fold)**
- Top-level KPI row showing the school's immediate fiscal health
- Quick drill-capable tiles linking to deeper views

**Section B: Budget Compliance & Variance Analysis**
- Planned vs Actual spend by category with variance indicators
- Category-wise burn rate visualization

**Section C: Revenue & Expense Flow**
- Fee collection pipeline vs operating expenses
- Cash position status (available cash vs committed spend)

**Section D: Forecasting & Projections**
- End-of-year budget outlook based on current burn rate
- Scenario modeling (what-if adjustments)

**Section E: Action Queue & Alerts**
- Items requiring Principal attention: overspending alerts, renewal expirations, pending approvals

**Section F: Historical Trend Charts**
- Monthly spend/revenue comparison across academic years
- Category composition over time

---

## 2. Key Performance Indicators (KPIs)

Each KPI card should be interactive—clicking opens a detailed breakdown or trend view.

| KPI ID | Name | Calculation | Units | Drill To |
|--------|------|-------------|-------|----------|
| **KP01** | Overall Budget Utilization | `SUM(actual_spend) / SUM(planned_budget)` | % | Category Breakdown |
| **KP02** | Cash Position (Net Liquidity) | `Cash_On_Hand - Committed_Expenditure` | ₹ | Bank Reconciliation |
| **KP03** | Fee Collection Rate | `Amount_Paid / Amount_Due` (%) | % | Invoice Detail Page |
| **KP04** | YoY Expense Growth | `(Current_Year_Spend - Previous_Year_Spend) / Previous_Year_Spend` | % | Historical Trend |
| **KP05** | Average Category Overrun | Weighted average of (actual/planned - 1) across categories | % | Category Report |
| **KP06** | Uncommitted Budget Balance | `Total_Planned_Budget - Spent - Committed_(POs)` | ₹ | Purchase Order Pipeline |
| **KP07** | Outstanding Vendor Payments | Sum of vendor_payments where status = 'pending_approval' or 'paid' not yet processed | ₹ | Vendor Payments List |
| **KP08** | Scholarship & Waiver Impact | Total approved waivers/scholarships reducing revenue | ₹ | Waiver Request Details |
| **KP09** | Payroll Commitment Ratio | `Payroll_Net / Total_Budget` | % | Payroll Details |
| **KP10** | Month-to-Date Spend Sparsity | Compare MoD spend to historical average at same point in year | % (index) | Monthly Burn Rate |

---

## 3. Dashboard Layout (Wireframe Concept)

```
+---------------------------------------------------------------+
|  Good morning, [Name]     | Principal Dashboard  | [Filter: 2025-26] |
+---------------------------------------------------------------+

+---------------------------------------------------------------+
|  [KP01]  [KP02]    [KP03]   [KP04]    [KP05]                  |
|  Budget Util.  Cash Position  Fee Coll.  YoY Growth  Avg. Overrun|
|  68%          ₹2.1Cr        72%         +12%           8%      |
+---------------------------------------------------------------+

+----------------------+------------------------------------+----------------------------+
| Budget Compliance    | Cash Flow Overview                 | Action Queue               |
| (Variances > 10%)    | (Revenues vs Expenses)             | (Items needing review)     |
|                      |                                    | • 3 POs awaiting approval  |
| [Category Bars Chart]| [Line: Revenue Line]               | • 2 late fee rule changes  |
| 📊 Spend by Category | [Area: Expense Stacked Chart]      | • EMI plan renewals due    |
+----------------------+------------------------------------+----------------------------+

+--------------------------------------------------------------------------------------------+
|  Mid-Year Projection & Risk Assessment                                                     |
|  Current trajectory suggests end-of-year budget shortfall of ₹X (based on Q1-Q2 burn rate).  |
|  Recommend: Adjust category allocations, defer non-essential purchases, or request surplus.  |
|  [Adjust Scenarios...] [Generate PDF Report]                                               |
+--------------------------------------------------------------------------------------------+

+----------------------+----------------------+----------------------+----------------------+
| Historical Trends    | Category Composition | Monthly Burn Rate    | Year-over-Year       |
| (Multi-Year Line)    | (Pie/Donut)          | (Stacked Bar Chart)  | Comparison (Table)   |
|                      |                      |                      |                      |
+----------------------+----------------------+----------------------+----------------------+
```

---

## 4. Charts & Visualizations

### 4.1 Budget Compliance & Variance Heatmap
**Type:** Horizontal bar chart with color-coded variance cells  
**Data Source:** `finance.budgets`, `finance.purchase_orders` (grouped by category), `finance.payroll_runs`  
**Display:** Each row = one budget category. Columns show Planned (₹), Actual (₹), Variance (₹ and %), and a colored indicator (green ≤10% over, yellow 10-25%, red >25%).  
**Interaction:** Clicking a row drills into transaction-level details for that category.

### 4.2 Monthly Burn Rate Trend
**Type:** Stacked area chart  
**Data Source:** Combined query aggregating `vendor_payments` and `payments` by month; `budgets` table for planned monthly allocation if available  
**Display:** X-axis = months of academic year; Y-axis = amount in ₹. Multiple layers = different expense categories (payroll, supplies, maintenance, etc.). Overlay a "planned burn" line for comparison.

### 4.3 Revenue vs Operating Expenses Flow
**Type:** Dual-line chart with shaded regions  
**Data Source:** `payments` (fee revenue), `vendor_payments` + `payroll_runs` (expenses)  
**Display:** Two lines: incoming fee collections (cumulative) and outgoing expenditures (cumulative). Shaded region between them shows net positive/negative cash position at each point.

### 4.4 Year-over-Year Expense Comparison
**Type:** Grouped bar chart  
**Data Source:** Aggregated spend from `purchase_orders`, `payroll_runs`, `vendor_payments` filtered by academic_year  
**Display:** Side-by-side bars for each major category (e.g., Staff, Academic Supplies, Infrastructure, Events) comparing current year to previous year. Color difference highlights growth/decline.

### 4.5 Category Composition (Current Spend Share)
**Type:** Donut/pie chart  
**Data Source:** Spend totals grouped by category from purchase orders and payroll  
**Display:** Proportion of total operational spend by category. Interactive segments highlight when hovered, showing absolute values and percentages.

### 4.6 Fee Collection Progress vs Target
**Type:** Gauges (semi-circular progress)  
**Data Source:** `invoices` table (amount_due, amount_paid) grouped by fee structure and grade level  
**Display:** One gauge per major fee category (e.g., Tuition, Exam Fees, Activity Fees) showing % collected toward annual target. Threshold markers indicate mid-year goal.

### 4.7 Pending Approvals Pipeline
**Type:** Vertical stack cards (not a chart)  
**Data Source:** `purchase_orders`, `vendor_payments`, `waiver_requests` where status is pending admin/principal action  
**Display:** Cards grouped by type (POs, Payment Releases, Waivers). Each card shows requester, amount, date requested, urgency indicator based on how long pending.

---

## 5. Tables & Data Grids

### 5.1 Budget Category Detail Table
**Columns:** Category | Academic Year | Planned Amount | YTD Actual | Variance (₹) | Variance (%) | Remaining Budget | Status Indicator  
**Sorting:** By variance percentage or remaining balance  
**Filtering:** By academic year, category, status (over/under budget)  
**Export:** CSV download of selected view

### 5.2 Active Purchase Orders Table
**Columns:** PO # | Vendor | Description | Amount | Status | Approved By | Request Date | Due Date  
**Actions per Row:** View Details, Approve/Reject (if action permitted), Add Payment

### 5.3 Payroll Summary Table
**Columns:** Pay Period | Employee Count | Gross Amount | Deductions | Net Amount | Cost Center/Department  
**Grouping:** Can group by department or staff category (teaching, administrative, support)

### 5.4 Invoice Aging Table (for Fee Revenue View)
**Columns:** Student | Class | Fee Structure | Amount Due | Amount Paid | Balance Due | Days Overdue | Status  
**Filters:** By overdue status, class, fee structure

---

## 6. Quick Actions (Prominently Available)

| Action | Location | Triggers | Notes |
|--------|----------|----------|-------|
| **+ New Budget Entry** | Toolbar, top-right | Opens form dialog to add/update planned amount for a category/year | Admin/Principal only |
| **Adjust Allocation** | From variance row in table | Modifies planned amount for a category (reallocation within existing budget) | Audit trail required |
| **Approve Selected POs** | PO table bulk action | Bulk approves multiple pending purchase orders | Requires confirmation |
| **Create Payment Release** | From PO detail page | Generates corresponding vendor_payment entry | Links to PO ID |
| **Generate Budget Report** | Header menu button | Exports current dashboard as PDF/PPT summary | For stakeholder meetings |
| **What-If Scenario Editor** | Forecast section | Temporarily adjusts assumptions to project outcomes | Does not modify live data |
| **Alert Rules Setup** | Settings panel | Configure thresholds (e.g., notify when category exceeds 90%) | Persistent user preference |

---

## 7. Drill-Down Pathways

Each major widget/table should support drill-down to increasing levels of detail:

1. **KPI Tile Drill:** Clicking any KPI → opens a dedicated page with trend history, contributing factors, and related items (e.g., KP01 Budget Utilization → Category-by-category breakdown)
2. **Chart Segment Drill:** Clicking a segment in a donut/bar chart → filters underlying tables to that category/time range
3. **Row-Level Drill:** Clicking a row in a budget category table → shows all transactions (POs, payments) that contributed to the actual spend for that category
4. **Date Range Selector:** Global filter at top right that applies across all visualizations (e.g., "This Semester", "Current Year", "Custom Range")
5. **Academic Year Toggle:** Switch between 2025-26, 2024-25, etc. for comparative analysis

---

## 8. Data Sources & Query Requirements

All queries must respect RLS policies—Principal can only see data belonging to their school (identified via JWT `app_metadata.school_id`).

### Required Data Queries (for implementation planning):

#### Q1: Combined Budget vs Actuals by Category
```sql
SELECT 
    b.category,
    b.academic_year,
    b.planned_amount AS planned,
    COALESCE(SUM(po.amount), 0) AS po_actual,
    COALESCE(SUM(vp.amount), 0) AS vp_actual,
    COALESCE(SUM(pr.net_amount), 0) AS payroll_actual
FROM finance.budgets b
LEFT JOIN finance.purchase_orders po ON po.category = b.po.school_id = b.school_id
LEFT JOIN finance.vendor_payments vp ON vp.purchase_order_id = po.id
LEFT JOIN finance.payroll_runs pr ON pr.school_id = b.school_id
WHERE b.school_id = ? AND b.academic_year = ?
GROUP BY b.category, b.academic_year, b.planned_amount;
```

#### Q2: Fee Collection Status
```sql
SELECT 
    status,
    SUM(amount_due) AS total_due,
    SUM(amount_paid) AS total_paid,
    SUM(amount_due - amount_paid) AS outstanding
FROM finance.invoices
WHERE school_id = (SELECT id FROM public.students WHERE ...); -- via RLS
```

#### Q3: Pending Approvals Count & Details
```sql
-- For POs
SELECT 'purchase_order' AS type, id, description, amount, created_at
FROM finance.purchase_orders
WHERE status = 'pending_approval' AND school_id = ?

UNION ALL

-- For Vendor Payments
SELECT 'vendor_payment' AS type, id, description, amount, created_at
FROM finance.vendor_payments
WHERE status = 'pending_approval' AND school_id = ?  -- through PO join

ORDER BY created_at ASC;
```

#### Q4: Monthly Burn Rate Aggregation
```sql
EXTRACT(MONTH FROM created_at) AS month,
EXTRACT(YEAR FROM created_at) AS year,
category,
SUM(amount) AS spend
FROM (
    SELECT created_at, amount, category FROM finance.purchase_orders
    UNION ALL
    SELECT created_at, amount, category FROM finance.vendor_payments
    UNION ALL
    SELECT to_char(pay_period, 'YYYY-MM') as created_at, net_amount, 'Payroll' AS category
    FROM finance.payroll_runs
) all_expenditures
WHERE school_id = ?
GROUP BY year, month, category;
```

#### Q5: Cash Position Calculation
```sql
-- Note: actual bank balance would come from bank_statement_lines matched/summed
SELECT 
    COALESCE(SUM(bsl.amount), 0) AS cash_on_hand,
    (SELECT SUM(amount) FROM finance.purchase_orders 
     WHERE school_id = ? AND status IN ('approved', 'pending_approval')) AS committed,
    (SELECT COALESCE(SUM(net_amount), 0) FROM finance.payroll_runs 
     WHERE school_id = ? AND status = 'paid') AS payroll_outstanding,
    (COALESCE(SUM(bsl.amount), 0) - 
     (SELECT SUM(amount) FROM finance.purchase_orders 
      WHERE school_id = ? AND status IN ('approved', 'pending_approval'))) AS net_liquidity
FROM finance.bank_statement_lines bsl
WHERE bsl.status = 'matched' AND school_id = ?;
```

---

## 9. Security & Access Controls

- **RLS Enforcement:** All database queries must include `school_id` filtering matching the user's JWT claim. The Principal role should be able to view all finance schema tables but not access other schools' data.
- **Write Permissions:** Only users with role `admin` or `principal` can insert/update budgets, approve POs/release payments, modify waiver statuses. These checks exist in RLS policies already defined in the schema.
- **Audit Trail:** All modifications to budget entries, approved payments, and waiver decisions should be logged via existing `audit.log_change()` triggers.
- **Data Confidentiality:** Individual employee payroll amounts should be visible only to the Principal and possibly HR-designated staff—not to other principals if multi-school.

---

## 18. Implementation Considerations (Non-UI)

### 18.1 Data Completeness Gaps to Address
- The `budgets` table currently stores only `planned_amount`—there is no field for actual spending tracking. Actuals are derived from purchase_orders, vendor_payments, and payroll_runs dynamically. This approach works but requires careful aggregation logic to avoid double-counting (e.g., PO amount vs. vendor_payment amount may represent the same spend at different stages).
- No direct link between budget categories and specific purchase order categories—some POs may lack a `category` field and default to "uncategorized". UI should allow assigning/correcting categories during PO creation.

### 18.2 Performance Optimization
- Pre-compute aggregates in background workers if large volumes of transactions cause latency on dashboard load. Consider materialized views for heavy calculations like monthly burn rates.
- Cache static budget lines (which rarely change) separately from dynamic spend figures that update frequently.

### 18.3 Responsive Design
- Primary dashboard layout should adapt from multi-column (desktop) to stacked single column (tablet/mobile). KPI row becomes horizontal scroll on narrow screens; charts stack vertically.
- Glassmorphic card style should maintain readability on all screen sizes—ensure text contrast meets WCAG AA standards over varied backdrops.

### 18.4 Integration Points
- Fee collection dashboard (parent/student view) shares invoice/payment data—should be consistent.
- Timetable app integration could correlate facility-use expenses with scheduled events.
- OMR attendance feed does not directly impact finances but informs student enrollment projections which affect fee revenue forecasts.
