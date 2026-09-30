# Finance Module — Feature Backlog

> Based on Maharashtra Cooperative Societies Act, Model Bye-Laws 2019, GST/TDS regulations,
> and best practices from Mygate, ADDA, ApnaComplex, SocietyBee, and MaintainEase.

---

## EPIC 1: Chart of Accounts & Double-Entry Accounting

### FIN-001: Define Chart of Accounts
**Priority:** P0 — Foundation
**Description:** Implement a configurable chart of accounts with the standard account groups required for cooperative housing society accounting. The chart must include **Assets** (bank accounts, cash in hand, fixed deposits, outstanding receivables, fixed assets like lift/generator/CCTV), **Liabilities** (outstanding vendor payments, advance maintenance received, security deposits, GST output liability, electricity/water deposits payable), **Income** (maintenance charges, non-occupancy charges, parking income, hall booking income, interest on FD, late payment interest, advertisement income), **Expenses** (staff salaries, security services, common area electricity, water & sewerage, lift AMC, generator AMC & fuel, repairs & maintenance, administrative expenses, audit & professional fees, insurance, miscellaneous), and **Funds** (sinking fund, repair fund, education fund, welfare fund). Each account head should have a code, name (EN + Marathi), type, parent group, and active/inactive flag. Admin-only management via API + mobile screen.

### FIN-002: Journal Entry Engine
**Priority:** P0 — Foundation
**Description:** Build a double-entry journal engine where every financial transaction creates balanced debit and credit entries. Each journal entry must have: date, narration (description), debit account + amount, credit account + amount, reference number, and created-by audit trail. The system must enforce that debits always equal credits. Support multi-line entries (e.g., a single bill payment that debits expense, credits bank, and credits TDS payable). All existing flows (bill generation, payment receipt, mark-paid) must be retrofitted to generate journal entries automatically. This is the legally required accounting standard for Indian housing society audits under the Maharashtra Cooperative Societies Act.

### FIN-003: Ledger View per Account
**Priority:** P1
**Description:** Provide a ledger screen for each account in the chart of accounts, showing all journal entries posted to that account in chronological order with running balance. Filters for date range and financial year (April–March). Each row shows: date, narration, counterparty account, debit amount, credit amount, and running balance. Export to PDF/Excel for auditor handoff. This replaces manual register maintenance required under Bye-law 141.

---

## EPIC 2: Billing & Invoicing

### FIN-004: GST-Compliant Invoice Generation
**Priority:** P1
**Description:** Enhance the existing bill generation to produce GST-compliant tax invoices when the society's annual maintenance collection exceeds ₹20 lakhs. Each invoice must contain: society's GSTIN, sequential invoice number, invoice date, member name and flat, HSN/SAC code (9995 for maintenance services), line-item breakdown with taxable value, CGST @ 9% and SGST @ 9% (or IGST @ 18%), total amount, and due date. GST applies on the **full amount** (not just the amount above ₹7,500) when monthly per-member charge exceeds ₹7,500. Store a `gstEnabled` flag and GSTIN in society config. Auto-generate the invoice PDF for download/sharing.

### FIN-005: Non-Occupancy Charges (NOC) Billing
**Priority:** P2
**Description:** Add support for non-occupancy charges — an additional levy on flats where the owner does not reside and has rented out the unit. As per Maharashtra Model Bye-Law 69, societies can charge up to 10% of the service charges as non-occupancy charges. The system should: detect flats marked as tenant-occupied (from the existing tenant module), automatically add NOC line items to the monthly bill for those flats, allow admin to configure the NOC percentage, and reflect the NOC in the bill breakdown. Generate journal entry: Dr. Member Receivable, Cr. NOC Income.

### FIN-006: Differential Billing (Area-Based, Equal, Slab)
**Priority:** P1
**Description:** Support multiple billing methods configurable per charge head: **Equal** (same amount for all flats regardless of size), **Per-Sqft** (rate × flat area — already partially implemented), and **Slab-based** (different rates for different flat size ranges, e.g., ₹3/sqft for <800 sqft, ₹2.5/sqft for 800–1200, ₹2/sqft for >1200). The billing structure screen should allow admin to pick the method per charge head. The bill preview should show a sample calculation for each method. This aligns with MaintainEase's hybrid calculation model used by Maharashtra societies.

### FIN-007: Recurring Bill Auto-Generation
**Priority:** P2
**Description:** Allow admin to configure automatic monthly bill generation on a fixed date (e.g., 1st of every month). The system should: store a billing schedule (day of month, active billing structure ID), auto-generate bills via a server-side cron/scheduled job, skip flats that already have a bill for that period (idempotent), send push notifications to all members when bills are generated, and log the auto-generation event. This eliminates the manual "Generate Bills" step each month. The admin can still override or regenerate manually.

---

## EPIC 3: Payment Collection & Reconciliation

### FIN-008: Multi-Mode Payment Tracking
**Priority:** P1
**Description:** Extend payment recording to track the payment mode: **Online (Razorpay)** (already implemented), **UPI** (manual entry with UTR number), **NEFT/RTGS** (manual entry with transaction reference), **Cheque** (cheque number, bank, date, clearance status), **Cash** (receipt number). Each payment record should capture: amount, mode, reference number, date received, date cleared (for cheques), and receipt number. Auto-generate a digital receipt (PDF) for each payment with society name, member name, flat, period, amount, mode, and receipt number — shared via push notification. Journal entry: Dr. Bank/Cash, Cr. Member Receivable.

### FIN-009: Bank Reconciliation
**Priority:** P2
**Description:** Provide a bank reconciliation screen where the admin/treasurer can: upload or paste a bank statement (CSV format from common banks — SBI, HDFC, ICICI, Kotak), auto-match transactions by amount + date + reference against recorded payments, flag unmatched entries for manual review, and generate the Bank Reconciliation Statement showing: balance as per bank, add uncleared deposits, subtract uncleared cheques, equals balance as per books. This is a mandatory report for the annual audit and required under Bye-law 141–147.

### FIN-010: Partial Payment & Advance Payment Handling
**Priority:** P1
**Description:** Handle partial payments correctly: when a member pays less than the full bill amount, record the partial payment, update `amountPaid` on the bill, keep the bill status as `ISSUED` (not `PAID`) until fully settled, and display the balance due. For advance payments (member pays for future months), create a credit balance in the member's account that auto-adjusts against future bills. The interest calculation (FIN-013) must use the **reduced principal** after partial payments, not the original bill amount. Journal entries must reflect the actual amount received.

---

## EPIC 4: Interest & Penalty on Late Payment

### FIN-011: Configurable Interest Rate
**Priority:** P0
**Description:** Allow admin to configure the late payment interest rate at the society level, with the following fields: annual interest rate (default 21% as per Model Bye-Law 70, but the 2026 amendment caps this at 12%), interest type (only **simple interest** — compound interest is prohibited under bye-laws), grace period in days after the due date before interest starts accruing (commonly 10–15 days), and whether the rate was approved in the last AGM (audit compliance field). Store the interest configuration with effective date so historical rates are preserved when changed.

### FIN-012: Automatic Interest Calculation Engine
**Priority:** P0
**Description:** Build an automated interest calculation engine that runs daily or on-demand. Formula: `Interest = Outstanding Principal × (Annual Rate / 365) × Days Delayed`. For each unpaid/partially-paid bill past the grace period: calculate interest from (due_date + grace_period) to today, use the **outstanding balance** (total - amountPaid) as principal, calculate per-bill (not on combined arrears — to avoid overcharging newer bills), store the calculated interest as a separate field on the bill, and add interest as a line item on the next bill or on a standalone interest debit note. Important: per SocietyBee and Maharashtra bye-law guidance, partial payments should be adjusted against **principal first, then interest** — adjusting interest first effectively imposes compound interest, which violates bye-laws.

### FIN-013: Interest Debit Notes
**Priority:** P2
**Description:** Generate monthly interest debit notes for members with overdue bills. Each debit note shows: member name, flat number, original bill reference, bill amount, amount paid, outstanding principal, days delayed, interest rate, calculated interest amount, and total due. The debit note should be viewable in the app and downloadable as PDF. Journal entry: Dr. Member Receivable (Interest), Cr. Interest Income.

---

## EPIC 5: TDS Compliance

### FIN-014: Vendor/Payee Master with PAN & TDS Section
**Priority:** P1
**Description:** Create a vendor/payee master registry to track all parties the society makes payments to. Each vendor record contains: name, PAN number, GSTIN (optional), address, contact details, vendor type (Contractor / Professional / Employee / Landlord), applicable TDS section (194C / 194J / 194I / 192 — auto-suggested based on vendor type), TDS rate (auto-filled from section but overridable), and active/inactive status. Without PAN, higher TDS rate (20%) applies automatically. This registry is the foundation for all TDS deductions and Form 26Q filing.

### FIN-015: TDS Deduction on Vendor Payments
**Priority:** P1
**Description:** When recording a vendor payment, the system must check if TDS is applicable based on: **Section 194C** (contractors — security, housekeeping, plumbing, painting, lift AMC): deduct 1% for individual/HUF or 2% for firms/companies when single payment > ₹30,000 or annual aggregate > ₹1,00,000. **Section 194J** (professionals — CA, lawyer, architect): deduct 10% when annual payment > ₹30,000. **Section 194I** (rent — if society rents out space): deduct 10% when annual rent > ₹2,40,000. Calculate TDS on the amount **excluding GST**. Record the gross amount, TDS deducted, and net amount paid. Generate journal entries: Dr. Expense (gross), Cr. TDS Payable (section-wise), Cr. Bank (net amount paid).

### FIN-016: TDS Payable Ledger & Deposit Tracking
**Priority:** P1
**Description:** Maintain section-wise TDS payable ledgers (194C Payable, 194J Payable, 194I Payable) that accumulate deducted TDS. Provide a dashboard showing: TDS deducted but not yet deposited (by section), deposit deadline (7th of the following month; March → April 30th), and overdue deposits highlighted in red (penalty: 1.5% per month). When the treasurer deposits TDS with the government, record the challan details (BSR code, challan serial, date) and auto-clear the TDS payable. Show a monthly TDS summary report.

### FIN-017: Form 26Q Data Export
**Priority:** P2
**Description:** Generate the data needed for quarterly TDS return filing (Form 26Q) in a format that can be directly imported into the TRACES portal or handed to the CA. The export should include: society's TAN, deductee PAN, section, date of payment, amount paid, TDS deducted, date of TDS deposit, challan details, and deductee type. Cover all four quarters (Apr–Jun → Jul 31, Jul–Sep → Oct 31, Oct–Dec → Jan 31, Jan–Mar → May 31). Also generate Form 16A certificates for vendors showing TDS deducted during the quarter.

### FIN-018: TAN Management & Configuration
**Priority:** P2
**Description:** Store the society's TAN (Tax Deduction Account Number) in the society configuration. Display a TDS compliance dashboard showing: TAN number, current quarter, deductions made this quarter, deposits made, pending deposits, upcoming filing deadline, and compliance status (Green/Yellow/Red). Alert admin 7 days before TDS deposit deadline (7th of month) and 15 days before quarterly return filing deadline.

---

## EPIC 6: Defaulter Management

### FIN-019: Defaulter Register & Aging Report
**Priority:** P0
**Description:** Auto-generate a defaulter register showing all members with unpaid dues past the due date. The report should include: member name, flat number, wing, total outstanding amount, principal breakdown by bill, interest accrued, days overdue, and aging buckets (0–30, 31–60, 61–90, 90+ days). As per the MCS Act, a member is classified as a **defaulter** after 3 months of non-payment. Flag such members distinctly. The register is the source document for legal notices under Section 91. Provide PDF export for committee meetings and legal proceedings.

### FIN-020: Automated Payment Reminders
**Priority:** P0
**Description:** Implement a multi-stage automated reminder system triggered by bill status and overdue duration. **Stage 1 — Bill Generated (Day 0):** Push notification + in-app alert with bill details and payment link. **Stage 2 — Due Date Approaching (3 days before):** Push notification reminder with "Pay before [date] to avoid interest". **Stage 3 — Overdue (Due date + 1):** Push notification + WhatsApp/SMS (if configured) with outstanding amount including interest. **Stage 4 — 15 Days Overdue:** Escalated reminder with warning about defaulter classification. **Stage 5 — 30 Days Overdue:** Final reminder before formal notice process. Each reminder should include: member name, flat, bill period, amount due, interest (if applicable), and a deep link to the payment screen. Admin can configure which stages are active and customize timing. WhatsApp delivery requires integration with WhatsApp Business API.

### FIN-021: Formal Defaulter Notice Generation
**Priority:** P2
**Description:** Generate formal defaulter notices as per Maharashtra bye-law requirements. The notice must show: principal outstanding with bill-wise breakdown, interest calculated separately (as required by law), total due, due date for response (minimum 30 days), warning about recovery proceedings under Section 101/154B-29 of MCS Act 1960, and society secretary's signature block. Generate three notice stages: **1st Reminder** (informal), **2nd Reminder** (formal with interest details), **3rd Notice** (legal notice under Section 91 — typically drafted by CA/lawyer based on the data exported from this system). Output as PDF, with a record of when each notice was generated and served.

### FIN-022: Member-Wise Statement of Account
**Priority:** P1
**Description:** Generate a complete statement of account for each member showing every financial transaction: bills raised, payments received, interest charged, adjustments, and running balance. Date range filterable (default: current financial year April–March). Each entry shows: date, description/narration, debit (charges), credit (payments), and running balance. This is the member's "passbook" view — available in the app for self-service, and as PDF for the member or auditor. Essential for dispute resolution when a member questions their balance.

---

## EPIC 7: Financial Reports & Dashboards

### FIN-023: Income & Expenditure Statement
**Priority:** P0
**Description:** Generate the Income & Expenditure Statement (the cooperative society equivalent of a P&L statement) on an **accrual basis** as required by the Maharashtra Cooperative Societies Act. **Income side:** maintenance charges earned, non-occupancy charges, parking income, hall booking income, interest on FD, late payment interest, and other income — grouped by account head. **Expenditure side:** salaries, security, electricity, water, repairs, lift AMC, generator, administrative expenses, audit fees, insurance, depreciation, and miscellaneous — grouped by account head. Bottom line shows surplus or deficit for the period. Filter by financial year (April–March) and month range. Export as PDF for auditor submission.

### FIN-024: Balance Sheet
**Priority:** P1
**Description:** Generate the Balance Sheet showing the society's financial position at a point in time. **Assets:** bank balances (savings + FD), cash in hand, outstanding receivables (members who haven't paid), fixed assets (with depreciation), and prepaid expenses. **Liabilities:** outstanding vendor payments, advance maintenance received, security deposits held, GST/TDS payable, and any loans. **Funds & Reserves:** sinking fund, repair fund, general reserve, and surplus from I&E statement. Assets must equal Liabilities + Funds. Generate as of March 31 (year-end) or any custom date. PDF export for audit.

### FIN-025: Receipts & Payments Account
**Priority:** P1
**Description:** Generate a cash-basis Receipts & Payments account showing actual money received and spent during the period (unlike the accrual-based I&E statement). **Receipts:** opening bank balance, maintenance collected, interest received, other receipts. **Payments:** salaries paid, vendor payments, utility bills, fund transfers, other payments, closing bank balance. This is a simpler, cash-flow-oriented report that complements the I&E statement. Required for audit under MCS Act.

### FIN-026: Budget vs Actual Variance Report
**Priority:** P2
**Description:** Allow admin to create an annual budget with estimated income and expenses per account head. Then generate a Budget vs Actual report showing: budgeted amount, actual amount, variance (₹ and %), and status (under/over budget) for each line item. Color-code: green (within 10%), yellow (10–25% variance), red (>25% overspend). This helps the committee track spending discipline and present to the AGM. The budget should be prepared before April (start of financial year) and presented for member approval.

### FIN-027: Expense Dashboard with Category Breakdown
**Priority:** P1
**Description:** Build a visual expense dashboard accessible to admin showing: **Total expenses** for the period (month/quarter/year), **Category-wise pie chart** (manpower ~41%, repairs ~17%, water+electricity ~21%, admin ~10%, other ~11% — based on industry benchmarks), **Month-over-month trend** (bar chart showing expense growth), **Top 5 expense categories** with amounts, **Top 5 vendors** by payment amount, and **Fund utilization** (sinking fund and repair fund usage vs contributions). Interactive: tap a category to drill into individual transactions. This gives the committee real-time visibility without waiting for the annual audit.

### FIN-028: Collection Efficiency Dashboard
**Priority:** P1
**Description:** Build a collection dashboard showing: **Collection rate** (% of billed amount collected, target: >95%), **On-time payment rate** (% paid before due date), **Outstanding dues** (total unpaid across all members), **Aging chart** (visual bar showing 0–30 / 31–60 / 61–90 / 90+ days buckets), **Wing-wise collection** (compare collection rates across wings A–G), **Month-over-month trend** (are collections improving or deteriorating?), and **Top defaulters** (members with highest outstanding). This dashboard drives proactive follow-up and is commonly used by treasurers in society management platforms like Mygate and ADDA.

### FIN-029: Trial Balance
**Priority:** P2
**Description:** Generate a Trial Balance report listing all accounts in the chart of accounts with their closing debit or credit balances as of a given date. Total debits must equal total credits. This is the first step in verifying books before preparing the I&E statement and balance sheet. Filter by financial year. Flag any imbalance. Export as PDF/Excel.

### FIN-030: GST Report (GSTR-3B / GSTR-1 Data)
**Priority:** P3
**Description:** If the society is GST-registered, generate a monthly GST summary showing: total taxable maintenance billed, CGST and SGST collected, input tax credit on vendor invoices (if applicable), net GST payable, and HSN-wise summary. Export data in the format needed for GSTR-3B (monthly summary) and GSTR-1 (outward supplies) filing on the GST portal. This is relevant only for societies with annual collection > ₹20 lakhs where per-member monthly charge > ₹7,500.

---

## EPIC 8: Fund Management

### FIN-031: Sinking Fund & Repair Fund Tracking
**Priority:** P1
**Description:** Maintain separate fund accounts for **Sinking Fund** (for major structural repairs, building insurance claims, reconstruction) and **Repair Fund** (for routine and preventive maintenance) as mandated by Maharashtra Model Bye-Laws. Track: monthly contributions from maintenance bills (configurable % or fixed amount per flat), withdrawals with committee resolution reference, current balance, FD investments made from the fund, and interest earned on FD. These funds **must not be mixed** with the regular maintenance account — enforce this by requiring a separate bank account or FD for each fund. Show fund health: is the current balance adequate for anticipated repairs?

### FIN-032: Fund Transfer Journal Entries
**Priority:** P2
**Description:** When the committee decides to transfer surplus to sinking/repair fund (typically done quarterly or annually after AGM), create a proper journal entry: Dr. Surplus/Income & Expenditure Account, Cr. Sinking/Repair Fund. When withdrawing from a fund for actual repairs, create: Dr. Repair Expense, Cr. Repair Fund (or Bank if paid from fund account). Track the resolution number/date from the committee meeting that approved the transfer or withdrawal. This ensures fund movements have a proper audit trail per bye-law requirements.

---

## EPIC 9: Audit & Compliance

### FIN-033: Audit-Ready Report Package
**Priority:** P2
**Description:** Generate a single downloadable audit package (ZIP of PDFs) containing all reports the statutory auditor needs for the annual audit: Income & Expenditure Statement, Balance Sheet, Receipts & Payments Account, Trial Balance, Bank Reconciliation Statement, Sinking Fund Statement, Repair Fund Statement, Defaulter Register with aging, TDS deduction summary (section-wise), and member-wise outstanding. Align to financial year April–March. This eliminates weeks of manual preparation and is the single biggest pain point for society treasurers.

### FIN-034: Section 80P Tax Exemption Tracking
**Priority:** P3
**Description:** Track income eligible for Section 80P exemption (cooperative society tax benefit). Maintenance income from members is generally exempt; income from non-members (rental, advertisement) is taxable. Interest income on investments with cooperative banks is exempt; interest from commercial banks is taxable (post Supreme Court ruling). The system should categorize each income head as 80P-exempt or taxable, and generate a summary for ITR-5 filing. Flag if total taxable income (interest from FDs in commercial banks, rental income from non-members) exceeds the basic exemption limit.

### FIN-035: Tax Audit Trigger Alert
**Priority:** P3
**Description:** If the society's annual receipts exceed ₹50 lakhs, a tax audit under Section 44AB is mandatory. Monitor total receipts during the financial year and alert the admin when receipts cross ₹40 lakhs (early warning) and ₹50 lakhs (audit required). Display the current year's total receipts on the finance dashboard.

---

## Priority Summary

| Priority | Count | Items |
|----------|-------|-------|
| **P0** | 6 | FIN-001, FIN-002, FIN-011, FIN-012, FIN-019, FIN-020, FIN-023 |
| **P1** | 12 | FIN-003, FIN-004, FIN-006, FIN-008, FIN-010, FIN-014, FIN-015, FIN-016, FIN-022, FIN-024, FIN-025, FIN-027, FIN-028, FIN-031 |
| **P2** | 11 | FIN-005, FIN-007, FIN-009, FIN-013, FIN-017, FIN-018, FIN-021, FIN-026, FIN-029, FIN-032, FIN-033 |
| **P3** | 3 | FIN-030, FIN-034, FIN-035 |

---

## Sources

- [Mygate — Chart of Accounts for Apartment Associations](https://mygate.com/blog/housing-society/chart-of-accounts-apartment-associations/)
- [Mygate — Double Entry Accounting for Housing Societies](https://mygate.com/blog/housing-society/double-entry-accounting-for-housing-societies/)
- [Mygate — Financial Reporting for Housing Societies](https://mygate.com/blog/housing-society/financial-reporting/)
- [Mygate — Late Payment Interest Calculation](https://mygate.com/blog/housing-society/late-payment-interest-calculation/)
- [Mygate — Society Billing & Accounting Guide](https://mygate.com/blog/housing-society/understanding-society-billing-and-accounting/)
- [ApnaComplex — Treasurer's Guide to TDS](https://blog.apnacomplex.com/2018/07/25/treasurers-guide-tds-apartment-associations-housing-societies/)
- [NoBrokerHood — TDS on Housing Societies](https://www.nobrokerhood.com/blog/tds-on-housing-society/)
- [ADDA — Community Budgeting for Owners Associations](https://blog.ind.adda.io/2026/04/community-budgeting-for-owners-associations/)
- [SocietyBee — Defaulter Management in Housing Societies](https://www.societybee.in/resources/blog/housing-society-defaulter-management)
- [MaintainEase — RWA Maintenance Charges Calculation](https://maintainease.in/blog/rwa-maintenance-charges-calculation)
- [MySocietyClub — Maharashtra Bye-Laws 65–71: Levy of Charges](https://mysocietyclub.com/bye-laws/maharashtra-cooperative-housing-society-bye-laws/levy-of-charges-of-society)
- [CMA Knowledge — Maintenance Charges in Maharashtra 2025](https://www.cmaknowledge.in/2025/11/maintenance-charges-in-maharashtra-housing-societies-2025-rules-bye-laws-gst-calculation-guide.html)
- [Jain Anurag & Associates — Housing Society Accounting & Legal Compliances](https://jainanuragassociates.com/knowledge-center/housing-society-accounting-legal-compliances-everything-you-need-to-know)
