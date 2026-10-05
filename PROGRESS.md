# FinanceTracker iOS — Development Progress

> **Recovery Guide**: If context is lost, read this file first.
> Re-read the last completed task's code, then execute the next `[ ] Pending` task.

---

## 🧭 Project Metadata
| Key | Value |
|-----|-------|
| App Name | FinanceTracker |
| Bundle ID | `com.local.FinanceTracker` |
| Minimum iOS | 17.0 |
| Persistence | SwiftData |
| Charts | Swift Charts (Apple built-in) |
| Language | Swift 5.10 / SwiftUI |
| Xcode Target | Free Developer Account (local sideload) |
| Workspace | `/Users/jasonkhaw/Documents/Coding/FinanceTracker/` |
| Current Version | `1.4.0` (Build `5`) |

---

## 🏷️ Versioning Strategy (Semantic Versioning `a.b.c`)
- **`a.x.x` (Major)**: Increment only when the user explicitly requests a major overhaul, milestone release, or breaking architectural redesign (e.g. `2.0.0`). When `a` increments, `b` and `c` reset to `0`.
- **`x.b.x` (Minor)**: Increment whenever useful new features, new UI workflows, or functional modules are added (e.g. `1.2.0`). When `b` increments, `c` resets to `0`.
- **`x.x.c` (Patch)**: Increment for routine bug fixes, style polish, micro-optimizations, or minor copy adjustments (e.g. `1.1.1`).
- **`CURRENT_PROJECT_VERSION` (Build)**: Strictly increments by `+1` on each deployment/build (`1` → `2` → `3`...).
- For every version change, update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in [project.yml](file:///Users/jasonkhaw/Documents/Coding/FinanceTracker/project.yml) and run `xcodegen generate`.

---

## 📐 Data Model Overview

```
Ledger          — top-level account container (Personal, Family, Travel…)
  └── Transaction — a single expense or income entry
        ├── Category  — user-defined category (Food, Transport, Salary…)
        └── Tag[]     — optional free-form tags (many-to-many)

Budget          — monthly spending limit per category per ledger
RecurringRule   — template for auto-generated recurring transactions
```

### SwiftData Entities
| Model | Key Fields |
|-------|-----------|
| `Ledger` | id, name, colorHex, icon, currency, createdAt |
| `Transaction` | id, amount, type(income/expense), date, note, ledger→, category→, tags→ |
| `Category` | id, name, icon, colorHex, type(income/expense/both) |
| `Tag` | id, name, colorHex |
| `Budget` | id, amount, period(monthly/weekly), category→, ledger→, startDate |
| `RecurringRule` | id, amount, note, frequency, nextDueDate, category→, ledger→, isActive |

---

## 🗂️ File Structure (Target)

```
FinanceTracker/
├── FinanceTrackerApp.swift
├── ContentView.swift
├── Models/
│   ├── Ledger.swift
│   ├── Transaction.swift
│   ├── Category.swift
│   ├── Tag.swift
│   ├── Budget.swift
│   └── RecurringRule.swift
├── ViewModels/
│   ├── LedgerViewModel.swift
│   ├── TransactionViewModel.swift
│   ├── BudgetViewModel.swift
│   └── RecurringViewModel.swift
├── Views/
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   └── SummaryCardView.swift
│   ├── Transactions/
│   │   ├── TransactionListView.swift
│   │   ├── TransactionRowView.swift
│   │   └── AddEditTransactionView.swift
│   ├── Categories/
│   │   ├── CategoryListView.swift
│   │   └── AddEditCategoryView.swift
│   ├── Ledgers/
│   │   ├── LedgerListView.swift
│   │   └── AddEditLedgerView.swift
│   ├── Charts/
│   │   ├── SpendingDonutChart.swift
│   │   └── TrendLineChart.swift
│   ├── Budgets/
│   │   ├── BudgetListView.swift
│   │   └── AddEditBudgetView.swift
│   ├── Recurring/
│   │   ├── RecurringListView.swift
│   │   └── AddEditRecurringView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Shared/
│       ├── IconPickerView.swift
│       ├── ColorPickerView.swift
│       └── EmptyStateView.swift
├── Services/
│   ├── CSVService.swift
│   ├── NotificationService.swift
│   └── RecurringService.swift
└── Extensions/
    ├── Color+Hex.swift
    ├── Date+Helpers.swift
    └── Double+Currency.swift
```

---

## ✅ Task Checklist

### Phase 0 — Foundation
- [x] **T-00**: Architecture design + PROGRESS.md created ← **(DONE)**
- [x] **T-01**: Xcode project scaffold — folder structure + placeholder files ← **(DONE)**
- [x] **T-02**: SwiftData models — all 6 entities + AppEnums ← **(DONE)**
- [x] **T-03**: App entry point — FinanceTrackerApp.swift + ContentView.swift (TabView) ← **(DONE)**
- [x] **T-04**: Extensions — Color+Hex, Date+Helpers, Double+Currency ← **(DONE)**

### Phase 1 — Category & Tag CRUD
- [x] **T-05**: CategoryListView + AddEditCategoryView ← **(DONE)**
- [x] **T-06**: TagListView + AddEditTagView ← **(DONE)**

### Phase 2 — Transaction CRUD
- [x] **T-07**: TransactionListView + TransactionRowView ← **(DONE)**
- [x] **T-08**: AddEditTransactionView ← **(DONE)**

### Phase 3 — Ledger Management
- [x] **T-09**: LedgerListView + AddEditLedgerView ← **(DONE)**
- [x] **T-10**: LedgerSwitcherView ← **(DONE)**

### Phase 4 — Dashboard & Summaries
- [x] **T-11**: DashboardView — monthly/weekly summary cards ← **(DONE)**
- [x] **T-12**: SummaryCardView — income vs. expense breakdown ← **(DONE)**

### Phase 5 — Advanced Charts
- [x] **T-13**: SpendingDonutChart ← **(DONE)**
- [x] **T-14**: TrendLineChart ← **(DONE)**

### Phase 6 — Budget System
- [x] **T-15**: BudgetListView + AddEditBudgetView ← **(DONE)**
- [x] **T-16**: NotificationService — local push for overspending alerts ← **(DONE)**

### Phase 7 — Recurring Transactions
- [x] **T-17**: RecurringListView + AddEditRecurringView ← **(DONE)**
- [x] **T-18**: RecurringService — auto-log engine ← **(DONE)**

### Phase 8 — Data I/O
- [x] **T-19**: CSVService — export ← **(DONE)**
- [x] **T-20**: CSVService — import ← **(DONE)**

### Phase 9 — Settings & Polish
- [x] **T-21**: SettingsView ← **(DONE)**
- [x] **T-22**: Final polish — search/filter, empty states, app icon ← **(DONE)**

### Phase 10 — v1.1 User Refinements (Localization, Aesthetics & Attachments)
- [x] **R-01**: Malaysian Ringgit (MYR / RM) default currency across all formatters, models, views, and data seeder ← **(DONE)**
- [x] **R-02**: Modern minimalist luxury app icon (geometric monochrome luxury emblem) generated & updated in AppIcon catalog ← **(DONE)**
- [x] **R-03**: Obsidian & White monochrome aesthetic (dynamic high-contrast monochrome accent, sleek dark gradient cards, monochrome palette) ← **(DONE)**
- [x] **R-04**: Receipt photo attachment support in `AddEditTransactionView` via `PhotosUI`, persistent storage, and indicator in `TransactionRowView` ← **(DONE)**

### Phase 11 — v1.2 Expense Splitter Module
- [x] **S-01**: Math expression evaluation engine (`MathExpressionEvaluator`) supporting arithmetic expressions in expense amounts ← **(DONE)**
- [x] **S-02**: SwiftData models (`SplitMember`, `SplitExpense`, `SplitSettlement`, auxiliary models) with schema registration ← **(DONE)**
- [x] **S-03**: Vision framework OCR receipt scanner (`ReceiptScannerService`) for itemized line item, tax, and fee extraction ← **(DONE)**
- [x] **S-04**: Itemized receipt splitting UI (`ReceiptItemAssignmentView`) with member avatar toggles and proportional tax/fee distribution ← **(DONE)**
- [x] **S-05**: Optimal debt simplification algorithm (`DebtSimplifier`) for minimizing cross-transfers and tracking member balances ← **(DONE)**
- [x] **S-06**: Full Expense Splitter UI (`SplitterMainView`, `SplitExpenseListView`, `SettlementView`, `AddEditSplitExpenseView`, `SplitMemberManagementView`) integrated into main TabView ← **(DONE)**
- [x] **S-07**: Comprehensive unit tests for math evaluation, debt simplification, receipt parsing, and model persistence (22/22 tests passed) ← **(DONE)**

### Phase 12 — v1.3 Multi-Group Splitter Architecture
- [x] **G-01**: `SplitGroup` SwiftData model with schema migration and group-level cascades ← **(DONE)**
- [x] **G-02**: Group creation & editing sheet (`AddEditSplitGroupView`) with icons, colors, and initial friend setup ← **(DONE)**
- [x] **G-03**: Interactive Group Switcher modal (`SplitGroupSwitcherView`) with unsettled spending metrics per group ← **(DONE)**
- [x] **G-04**: Complete group isolation across member lists, expense feeds, and debt simplification settlements ← **(DONE)**
- [x] **G-05**: Automated group isolation unit tests (`testSplitGroupIsolationAndCascade`, 23/23 tests passed) ← **(DONE)**

### Phase 13 — v1.4 Gemini AI Multimodal Receipt Scanning
- [x] **AI-01**: `GeminiReceiptScannerService` integrating Google Gemini Vision API (`gemini-3.5-flash-lite`) with structured JSON parsing ← **(DONE)**
- [x] **AI-02**: AppStorage persistence for Gemini API key & model selection with dedicated Settings UI in `SettingsView` ← **(DONE)**
- [x] **AI-03**: Quick in-scanner API key configuration sheet and live AI/OCR status indicator in `ReceiptItemAssignmentView` ← **(DONE)**
- [x] **AI-04**: Automatic fallback to offline Apple Vision OCR when API key is missing or offline ← **(DONE)**
- [x] **AI-05**: Automated unit tests for Gemini API response & markdown fence parsing (25/25 tests passed) ← **(DONE)**

### Phase 14 — v1.4.1 Embedded Gemini Configuration & Seamless UI
- [x] **C-01**: Secure `AppSecrets` configuration (`FinanceTracker/Config/AppSecrets.swift`) embedding verified Google Gemini API key and default `gemini-3.5-flash-lite` model ← **(DONE)**
- [x] **C-02**: `GeminiReceiptScannerService` automated defaults and resolution methods (`isAvailable`, `effectiveApiKey`, `effectiveModel`) ← **(DONE)**
- [x] **C-03**: Cleaned `ReceiptItemAssignmentView` to automatically utilize pre-configured AI with sleek "Active" status indicator, removing modal friction ← **(DONE)**
- [x] **C-04**: Updated `SettingsView` with dedicated status card confirming Gemini 3.5 Flash Lite is pre-configured, ready, and active ← **(DONE)**
- [x] **C-05**: Automated unit tests for `AppSecrets` resolution and default configurations (26/26 tests passed) ← **(DONE)**

### Phase 15 — v1.4.2 Malaysian 5-Sen Rounding Adjustment Support
- [x] **RND-01**: `MalaysianRounding` utility (`FinanceTracker/Services/MalaysianRounding.swift`) implementing official Bank Negara Malaysia 5-sen rounding mechanism ← **(DONE)**
- [x] **RND-02**: `ReceiptScannerService` and `GeminiReceiptScannerService` extraction of explicit and implicit rounding adjustments from receipts ← **(DONE)**
- [x] **RND-03**: `ReceiptItemAssignmentView` integration with rounding input field, 5-sen auto-calculation button, accurate Grand Total display, and penny-reconciliation for member shares ← **(DONE)**
- [x] **RND-04**: `SplitExpense` model and `AddEditSplitExpenseView` persistence of `roundingAmount` with seamless total synchronization ← **(DONE)**
- [x] **RND-05**: Automated unit tests for Malaysian rounding rules, Gemini and Apple Vision OCR rounding extraction, and SwiftData persistence (31/31 tests passed) ← **(DONE)**

### Phase 16 — v1.5.0 Expense Splitter UX, Inspection & Editing Enhancements
- [x] **UX-01**: Expense deletion in Splitter (`AddEditSplitExpenseView` dedicated red delete button with confirmation alert, `SplitExpenseListView` swipe-to-delete, context menu, and `.onDelete`) ← **(DONE)**
- [x] **UX-02**: Zoomable full-screen receipt inspector (`ReceiptImageViewer`) with pinch-to-zoom (1x–5x), double-tap zoom, and panning gesture to verify items against original bill ← **(DONE)**
- [x] **UX-03**: Removed out-of-place Gemini AI Vision badge from `ReceiptItemAssignmentView` to restore seamless minimalist luxury monochrome styling ← **(DONE)**
- [x] **UX-04**: Interactive line item editing (`editItemSheet`) allowing users to tap any recognized item to fix misidentified dish names, quantities, and prices ← **(DONE)**
- [x] **UX-05**: Ergonomic UI enhancements with enlarged 44pt-tall "Add Line Item" button, expanded member avatar toggle tap targets, and spacious sheet presentations ← **(DONE)**
- [x] **UX-06**: Verified all 31 unit tests pass under iOS 18 / Xcode 16 environment ← **(DONE)**

### Phase 17 — v1.6.0 Cross-Group Member Profile Reuse & Quick-Selection
- [x] **MEM-01**: `ExistingFriend` model (`FinanceTracker/Models/ExistingFriend.swift`) and `Collection<SplitMember>.uniqueFriendProfiles(excludingNames:)` extracting unique friend profiles across groups while filtering out current user / "You" and preserving the latest avatar settings ← **(DONE)**
- [x] **MEM-02**: `AddEditSplitGroupView` integration with `GroupMemberDraft` and horizontal "Add from Existing Friends" avatar pills, allowing 1-tap addition of friends (e.g. Alex) with their exact name, icon, and theme color preserved ← **(DONE)**
- [x] **MEM-03**: Intelligent name input matching in `AddEditSplitGroupView`: typing an existing friend's name automatically syncs and applies their existing avatar icon and colorHex ← **(DONE)**
- [x] **MEM-04**: `SplitMemberManagementView` "Add from Other Groups" one-tap quick-add section and form-level "Pick from Existing Friends" picker for adding existing contacts to existing groups ← **(DONE)**
- [x] **MEM-05**: Strict SwiftData group isolation preserved: each group receives its own isolated `SplitMember` record, preventing debt/settlement leakage between groups ← **(DONE)**
- [x] **MEM-06**: Automated unit tests (`testCrossGroupMemberProfileReuse`, `testUniqueFriendProfilesExclusion`) in `SplitterTests.swift` with all 33 unit tests passing (33/33) ← **(DONE)**

### Phase 18 — v1.6.0 Appearance (Light/Dark Mode), Camera Icon & Versioning Refinements
- [x] **THM-01**: Appearance switcher (`Light` / `Dark` / `System`) in `SettingsView` defaulting to Light Mode, with window-wide `preferredColorScheme` reactivity in `FinanceTrackerApp` and `ContentView` ← **(DONE)**
- [x] **THM-02**: Comprehensive white & black monochrome color overhaul: added `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor` to `project.yml`, applied `.tint(.primary)` globally on `WindowGroup` and `TabView`, eliminated all `Color.accentColor` references across all views in favor of `.primary`, and added `.buttonStyle(.plain)` to navigation bar pills so all toolbar items, list icons, and tab items render crisp black on white ← **(DONE)**
- [x] **THM-03**: Fixed missing camera icon in Scan Receipt: replaced generic button labels with explicit `Image(systemName: "camera.fill")` in `ReceiptItemAssignmentView` and `camera.viewfinder` in `AddEditSplitExpenseView` ← **(DONE)**
- [x] **THM-04**: Added `NSCameraUsageDescription` to `Info.plist` and `project.yml` for receipt scanning permissions ← **(DONE)**
- [x] **THM-05**: Fixed in-app versioning: configured `CFBundleShortVersionString` and `CFBundleVersion` variable substitution, showing `v1.6.0 (Build 9)` in Settings ← **(DONE)**
- [x] **THM-06**: Verified all 33 unit tests pass in iOS Simulator environment ← **(DONE)**

### Phase 19 — v1.7.0 Back Tap Quick Bookkeeping with Gemini AI Vision
- [x] **BT-01**: Registered URL Scheme `financetracker://` in `project.yml` and `FinanceTracker/Info.plist` with support for `financetracker://backtap` and `financetracker://quick-scan` routes ← **(DONE)**
- [x] **BT-02**: Added `NSPhotoLibraryUsageDescription` in `project.yml` and `Info.plist` for screenshot detection fallback ← **(DONE)**
- [x] **BT-03**: Built `AutoBookkeepingResult` and `GeminiReceiptScannerService.scanForAutoBookkeeping(image:)` with optimized prompt and JSON schema extracting merchant, amount, category, date, line items, tax, service fees, and rounding adjustments ← **(DONE)**
- [x] **BT-04**: Created `BackTapScreenshotService` (`FinanceTracker/Services/BackTapScreenshotService.swift`) seamlessly reading receipts from `UIPasteboard.general.image` or recent screenshots in `smartAlbumScreenshots` ← **(DONE)**
- [x] **BT-05**: Created `BackTapQuickScanView` (`FinanceTracker/Views/Transactions/BackTapQuickScanView.swift`) with monochromatic black & white styling, glowing scan beam animation, tap-to-zoom receipt inspection, large editable amount display, auto-matched categories, ledger selection, expandable breakdown, and 1-tap save with haptic feedback ← **(DONE)**
- [x] **BT-06**: Integrated URL routing in `ContentView.swift` (`.onOpenURL`) and state binding in `AppState.swift` (`showBackTapScanner`, `backTapInitialImage`) ← **(DONE)**
- [x] **BT-07**: Added dedicated Back Tap setup section in `SettingsView.swift` featuring 3-step Apple Shortcuts instructions, 1-tap URL copy button, and "Test Back Tap Scanner Now" launcher ← **(DONE)**
- [x] **BT-08**: Created automated unit tests (`testGeminiAutoBookkeepingParsing`, `testGeminiAutoBookkeepingImplicitRoundingReconciliation`) in `SplitterTests.swift`, achieving 100% pass rate across all 35 tests (35/35 passed) ← **(DONE)**

### Phase 20 — v1.8.0 Monthly Spending Breakdown, MoM/YoY Comparison & Chart Icon Inversion Fix
- [x] **CMP-01**: Top `TransactionComparisonCard` (`FinanceTracker/Views/Transactions/TransactionComparisonCard.swift`) supporting This Month vs Last Month (MoM) and This Year vs Last Year (YoY) with exact dollar amounts, percentage differences, and collapsible state ← **(DONE)**
- [x] **CMP-02**: Rich monthly section headers in `TransactionListView` displaying month expense totals, income, and MoM differences vs previous month ← **(DONE)**
- [x] **CMP-03**: `MonthBreakdownSheet` (`FinanceTracker/Views/Transactions/MonthBreakdownSheet.swift`) providing 1-tap comprehensive month spending overview, category distribution bars, daily average, and MoM insights ← **(DONE)**
- [x] **CMP-04**: Fixed Income vs Expenses icon inversion across `AppEnums.swift`, `DashboardView.swift`, `TrendLineChart.swift`, and `CSVService.swift` where Income mistakenly used `arrow.down` (⬇️) and Expenses used `arrow.up` (⬆️) ← **(DONE)**
- [x] **CMP-05**: Extended `Date+Helpers.swift` with `startOfYear`, `endOfYear`, and `isSameYear` methods ← **(DONE)**
- [x] **CMP-06**: Verified all 35 automated tests pass (35/35 passed), bumped version to `v1.8.0 (Build 11)` ← **(DONE)**

### Phase 21 — v1.8.0 English-Only Localization, Standalone Transactions & Category-Level Spending Comparisons in Charts
- [x] **ENG-01**: Eliminated all Chinese text across the entire codebase (`SettingsView`, `BackTapQuickScanView`, `TransactionListView`, `MonthBreakdownSheet`), enforcing a strict 100% English UI ← **(DONE)**
- [x] **ENG-02**: Restructured `TransactionListView` as a standalone, distraction-free transaction history ledger, removing the top comparison banner for a clean minimalist experience ← **(DONE)**
- [x] **ENG-03**: Co-located all spending comparisons and analytical charts inside the Charts tab (`ChartsView.swift`), creating a unified visual insights center ← **(DONE)**
- [x] **ENG-04**: Created `CategorySpendingComparisonCard` (`FinanceTracker/Views/Charts/CategorySpendingComparisonCard.swift`) providing category-by-category comparisons (e.g. Food & Dining, Transport, Shopping) across MoM and YoY with clean percentage pills, dual-bar indicators, and top-5 category capping with expansion toggle ← **(DONE)**
- [x] **ENG-05**: Verified all 35 automated tests pass (35/35 passed) and bumped build version to `v1.8.0 (Build 12)` ← **(DONE)**

### Phase 22 — v1.8.0 Historical Month Navigation, Executive Month Conclusion & Standalone Month Ledger
- [x] **NAV-01**: Interactive Month Navigator in `ChartsView.swift` featuring `< Month YYYY >` stepper controls, quick month dropdown menu, and a "Today" quick-return button to easily explore 3, 4, or any number of months in the past ← **(DONE)**
- [x] **NAV-02**: Executive `MonthConclusionCard` (`FinanceTracker/Views/Charts/MonthConclusionCard.swift`) providing a comprehensive summary of any chosen month: total spending, income, net savings/deficit, MoM spending change narrative, top spending category, and a direct "View All (x) Transactions" button ← **(DONE)**
- [x] **NAV-03**: Parameterized `SpendingDonutChart` and `CategorySpendingComparisonCard` with `targetDate: Date`, dynamically updating category distributions and MoM/YoY comparisons for the selected historical month ← **(DONE)**
- [x] **NAV-04**: Itemized Transaction Ledger inside `MonthBreakdownSheet.swift`, allowing users to tap into any month and inspect every transaction, view receipt images, and edit transactions directly ← **(DONE)**
- [x] **NAV-05**: Horizontal Month Filter Bar & Executive Summary Banner in `TransactionListView.swift`, giving users instant one-tap access to past months (e.g. 3 or 4 months ago) with a clean ledger view and key monthly metrics ← **(DONE)**
- [x] **NAV-06**: Confirmed 100% English UI compliance (0 Chinese characters across codebase), passed all 35 unit tests (35/35 passed), and bumped build version to `v1.8.0 (Build 13)` ← **(DONE)**

### Phase 23 — v1.8.0 Bank Accounts, Total Money & Net Worth Management
- [x] **ACC-01**: `Account` SwiftData model (`FinanceTracker/Models/Account.swift`) and `AccountType` (`AppEnums.swift`) supporting Bank Accounts, Savings, Credit Cards, Cash Wallets, E-Wallets, and Investments with starting balance, live computed balance, masked digits, and customizable theme cards ← **(DONE)**
- [x] **ACC-02**: Executive Total Money & Net Worth computation: aggregates total liquid money in bank accounts (checking + savings), cash holdings, and total net worth (assets minus credit card debt) ← **(DONE)**
- [x] **ACC-03**: `DashboardBankAccountsSection` (`FinanceTracker/Views/Accounts/DashboardBankAccountsSection.swift`) on `DashboardView`: Apple Wallet-style horizontal card carousel with live balances, executive Total Bank Money badge, and "+ Add Account" quick action ← **(DONE)**
- [x] **ACC-04**: Dedicated `AccountsHubView` (`FinanceTracker/Views/Accounts/AccountsHubView.swift`) with executive net worth summary, category filters (All, Banks, Savings, Cards, Cash), and comprehensive account management ← **(DONE)**
- [x] **ACC-05**: `AddEditAccountView` (`FinanceTracker/Views/Accounts/AddEditAccountView.swift`) featuring popular bank quick chips (Maybank, CIMB, Public Bank, RHB, Hong Leong, Touch 'n Go, Cash, Chase, etc.), live card preview, color themes, icon picker, and starting balance ← **(DONE)**
- [x] **ACC-06**: `AccountDetailView` (`FinanceTracker/Views/Accounts/AccountDetailView.swift`) with bank card hero, financial stats, 1-tap balance reconciliation against real bank statements, and itemized transaction ledger ← **(DONE)**
- [x] **ACC-07**: `TransferFundsSheet` (`FinanceTracker/Views/Accounts/TransferFundsSheet.swift`) enabling seamless fund transfers between bank accounts with automated double-entry transactions ← **(DONE)**
- [x] **ACC-08**: Transaction integration in `AddEditTransactionView.swift`, `TransactionRowView.swift`, and `BackTapQuickScanView.swift` allowing transactions to be attributed to specific bank accounts ← **(DONE)**
- [x] **ACC-09**: Comprehensive automated unit tests in `AccountTests.swift` covering balance calculations, credit card debt, reconciliation, and net worth; all 41 unit tests passed (41/41 passed); bumped build version to `v1.8.0 (Build 14)` ← **(DONE)**

### Phase 24 — v1.8.0 Dashboard Streamlining, Bank Balance Privacy, Local Analytics Guarantee & Income vs Expenses Rebuild
- [x] **DSH-01**: Removed redundant "Personal overall balance" hero card from `DashboardView.swift`, promoting Bank Accounts and Total Money as the primary hero focus ← **(DONE)**
- [x] **SEC-01**: Added balance privacy masking (`hideAccountBalances`) via persistent `AppStorage` with interactive eye toggle buttons across `DashboardBankAccountsSection`, `AccountsHubView`, and `AccountDetailView` (masking sensitive amounts with `••••••`) ← **(DONE)**
- [x] **API-01**: Verified and guaranteed that Charts summaries and conclusions (`MonthConclusionCard`, `TrendLineChart`, `SpendingDonutChart`) run 100% on-device using local Swift algorithms with 0 Gemini API requests, ensuring zero quota consumption ← **(DONE)**
- [x] **CHT-01**: Rebuilt `TrendLineChart.swift` completely: replaced colliding AreaMarks with paired side-by-side grouped bars (`BarMark` with `position(by:)`), added a clean dual trendline toggle, active month metrics strip (+Income, −Expenses, Net), calendar-accurate month filtering, and tap-to-select synchronization with `ChartsView` ← **(DONE)**
- [x] **TST-01**: Verified 100% English compliance, passed all 41 automated unit tests (41/41 passed), and bumped build version to `v1.8.0 (Build 15)` ← **(DONE)**

### Phase 25 — v1.8.0 Note-First Transaction Ledger Display
- [x] **TXN-01**: Enhanced `TransactionRowView.swift` to prioritize `transaction.note` as the primary title rather than generic category names (e.g. displaying specific purchases like "Chicken Rice with Ice Lemon Tea", "Grab to KL Sentral", "Uniqlo T-Shirt"), so users immediately know exactly what was purchased ← **(DONE)**
- [x] **TXN-02**: Relocated category context to the secondary subtitle alongside date and account badges (e.g. `04 Oct · Food & Dining · Maybank`), providing complete purchase clarity at a glance with fallback to category name if no note exists ← **(DONE)**
- [x] **TXN-03**: Automatically active across all transaction views: `TransactionListView`, `DashboardView` recent transactions section, `MonthBreakdownSheet`, and `AccountDetailView` ← **(DONE)**
- [x] **TXN-04**: Confirmed 100% English UI compliance, verified all 41 automated unit tests pass (41/41 passed), and bumped build version to `v1.8.0 (Build 16)` ← **(DONE)**

### Phase 26 — v1.8.1 Date-Segmented Transactions & Flexible Month Filtering
- [x] **TXN-05**: Re-architected `TransactionListView.swift` with date-segmented grouping (each calendar day rendered in its own clean section/card with header e.g. `Today · 4 Oct 2026`, `Yesterday · 3 Oct 2026`, `Fri, 2 Oct 2026`), eliminating cluttered lists and crowded dates ← **(DONE)**
- [x] **TXN-06**: Integrated daily financial summaries in every date section header, displaying daily net spending (`-MYR 38.50`) and income in high-contrast luxury styling ← **(DONE)**
- [x] **TXN-07**: Implemented prominent, always-visible Month Selector system: horizontal capsule pill bar (`All`, `Oct 2026`, `Sep 2026`, `Aug 2026`, etc.) plus a dedicated calendar dropdown menu in the navigation bar (`[ 📅 Oct 2026 ▾ ]`) allowing users to easily select October, September, August, or All Months anytime ← **(DONE)**
- [x] **TXN-08**: Updated `MonthBreakdownSheet.swift` with date-segmented grouping; verified 100% English compliance, added `testDaySectionDisplay()` to `ExtensionsTests.swift`; all 42 automated tests pass (42/42 passed); bumped version to `v1.8.1 (Build 17)` ← **(DONE)**

### Phase 27 — v1.8.2 Mandatory Transaction Name, Food Review Notes & Long-Press Photo/Note Preview
- [x] **TXN-09**: Added mandatory `name` field to `Transaction` model and `AddEditTransactionView.swift`, enforcing that every transaction must have a name (e.g. "Curry Laksa", "Starbucks Flat White", "Uniqlo T-Shirt") before saving ← **(DONE)**
- [x] **TXN-10**: Main title in `TransactionRowView` displays the item `name`, with `note` dedicated for supplementary reviews, food ratings, and comments. Added media indicator badges (`photo.fill` and `text.bubble.fill`) on rows with attached photos or notes ← **(DONE)**
- [x] **TXN-11**: Built `TransactionPreviewCard.swift` and integrated iOS native `.contextMenu(preview:)` across all transaction lists (`TransactionListView`, `DashboardView`, `MonthBreakdownSheet`, `AccountDetailView`), enabling users to long-press any transaction to instantly view its food/receipt photo, rating/review note, and metadata ← **(DONE)**
- [x] **TXN-12**: Built `TransactionDetailSheet.swift` for full-screen inspection of photos and food reviews; added automated tests in `LedgerTests.swift`; all 43 tests pass (43/43 passed); bumped version to `v1.8.2 (Build 18)` ← **(DONE)**

### Phase 28 — v1.8.3 SwiftData Schema Lightweight Migration & Resilient Store Recovery
- [x] **MIG-01**: Diagnosed `SwiftData.SwiftDataError error 1` in `FinanceTrackerApp.swift:44` caused by non-optional `var name: String` in `Transaction.swift`, which prevented SQLite lightweight migration from adding the column to the existing persistent store ← **(DONE)**
- [x] **MIG-02**: Changed `var name: String? = nil` to optional in `Transaction.swift` so SQLite can perform zero-downtime lightweight column additions on existing databases ← **(DONE)**
- [x] **MIG-03**: Added resilient fallback and self-healing store recovery in `FinanceTrackerApp.swift` to clean up incompatible SQLite stores or fall back to in-memory mode rather than throwing fatal error ← **(DONE)**
- [x] **MIG-04**: Verified 100% English compliance, passed all 43 automated unit tests, and bumped version to `v1.8.3 (Build 19)` ← **(DONE)**

### Phase 29 — v1.8.4 Category Expense Explorer & Highest-First Sorting Drilldown
- [x] **CAT-01**: Created `CategoryExpensesDetailSheet` (`FinanceTracker/Views/Charts/CategoryExpensesDetailSheet.swift`) providing a comprehensive category-level expense inspector for the selected month with executive hero metrics (Total Spent, % of Month Spend, Transaction Count, Average Spend per Transaction, Highest Single Transaction) ← **(DONE)**
- [x] **CAT-02**: Implemented strict **Highest Expense First** (`$0.amount > $1.amount`) default sorting with visual rank badges (`#1`, `#2`, `#3`...) and alternative sort options (Lowest First, Newest Date, Oldest Date) ← **(DONE)**
- [x] **CAT-03**: Integrated horizontal category switcher pill bar at the top of `CategoryExpensesDetailSheet`, allowing users to effortlessly switch between categories (e.g. Food & Dining, Transport, Groceries, Shopping) with live expense totals without closing the sheet ← **(DONE)**
- [x] **CAT-04**: Added native long-press preview (`TransactionPreviewCard`) and full-screen detail view (`TransactionDetailSheet`) inside the category drill-down sheet to inspect food photos, ratings, and reviews ← **(DONE)**
- [x] **CAT-05**: Added interactive category drill-down handlers (`onSelectCategory`) to both `CategorySpendingComparisonCard` and `SpendingDonutChart` in `ChartsView.swift` ← **(DONE)**
- [x] **CAT-06**: Built dedicated "Category Expense Explorer" card in `ChartsView.swift` showing ranked category chips with expense amounts, count, and instant 1-tap inspection ← **(DONE)**
- [x] **CAT-07**: Added automated unit test `testCategoryMonthlyExpenseHighestFirstSorting()` in `LedgerTests.swift`; verified 100% English compliance (0 Chinese characters); all 44 unit tests pass; bumped build version to `v1.8.4 (Build 20)` ← **(DONE)**

### Phase 30 — v1.8.4 Git Repository Initialization, API Key Protection & GitHub Remote Synchronization
- [x] **GIT-01**: Secured Google Gemini API key by extracting raw credentials into git-ignored `Secrets.local.plist`, refactoring `AppSecrets.swift` to dynamically resolve keys locally, and providing public template `Secrets.example.plist` ← **(DONE)**
- [x] **GIT-02**: Configured comprehensive `.gitignore` protecting local secrets, environment files, Xcode user state (`xcuserdata`), and build artifacts ← **(DONE)**
- [x] **GIT-03**: Created remote GitHub repository `https://github.com/ado0330/FinanceTracker` under user account `ado0330` ← **(DONE)**
- [x] **GIT-04**: Created `AGENTS.md` and `.agents/rules/release_and_progress_sync.md` mandating that every future agent synchronize user requirements into `PROGRESS.md` and automatically push to GitHub upon version bumps ← **(DONE)**
- [x] **GIT-05**: Initialized git repository on `main` branch, committed initial snapshot, created release tag `v1.8.4`, and pushed code & tags to GitHub ← **(DONE)**

### Phase 31 — v1.9.0 iPad Native Adaptation & Cross-Device Real-time Cloud Synchronization
- [x] **PAD-01**: Configured iPad target support in `project.yml` with `TARGETED_DEVICE_FAMILY: "1,2"`, full iPad orientation support (`UISupportedInterfaceOrientations~ipad`), and `UIRequiresFullScreen: NO` for Stage Manager and iPad Split View ← **(DONE)**
- [x] **PAD-02**: Implemented iPadOS native `NavigationSplitView` sidebar on regular width classes (`ContentView.swift`) with luxury monochrome styling, quick transaction shortcut (`Cmd+N`), tab switching keyboard shortcuts (`Cmd+1..6`), and seamless compact `TabView` fallback on iPhone ← **(DONE)**
- [x] **PAD-03**: Built adaptive multi-column iPad layouts for `DashboardView.swift` (left: period controls & summary cards, right: recent transactions ledger) and `ChartsView.swift` (left: MoM comparisons & category explorer, right: spending donut & trend line chart) ← **(DONE)**
- [x] **SYNC-01**: Designed zero-cost Supabase PostgreSQL cloud sync schema (`supabase_schema.sql`) with UUID primary keys, `updated_at` triggers, `deleted_at` soft-delete tombstoning, Row Level Security policies, and Realtime publication (`supabase_realtime`) ← **(DONE)**
- [x] **SYNC-02**: Built robust Cloud Sync Engine (`FinanceTracker/Services/Sync/SyncEngine.swift`) & DTO models (`SyncModels.swift`) featuring offline-first bidirectional sync, Last-Write-Wins conflict resolution, WebSocket Realtime push notifications, and safe SQLite reconciliation ← **(DONE)**
- [x] **SYNC-03**: Created luxury `SyncStatusBadge` component (`FinanceTracker/Views/Shared/SyncStatusBadge.swift`) integrated into iPad sidebar, iPhone navigation toolbars, with live sync state animation (synced, syncing, offline, error) and 1-tap manual sync trigger ← **(DONE)**
- [x] **SYNC-04**: Added dedicated Real-Time Cloud Sync section in `SettingsView.swift` with live connection status, custom Supabase URL and Anon Key inputs, manual "Sync Now" button, and interactive 2-minute setup guide modal ← **(DONE)**
- [x] **SYNC-05**: Added comprehensive automated unit tests in `SyncTests.swift`; verified all 47 tests pass on both iPhone 17 and iPad Air 11-inch (M4) simulators (47/47 passed); guaranteed 100% English UI (0 Chinese characters); bumped version to `v1.9.0 (Build 21)` ← **(DONE)**

### Phase 32 — v1.9.1 Local Secrets Cloud Credentials Protection & Automated Configuration
- [x] **SEC-02**: Extended `AppSecrets.swift` to securely resolve `SUPABASE_URL` and `SUPABASE_ANON_KEY` from git-ignored `Secrets.local.plist` and environment variables with zero risk of git leakage ← **(DONE)**
- [x] **SEC-03**: Updated `SyncEngine.swift` to automatically fall back to `AppSecrets.supabaseURL` and `AppSecrets.supabaseAnonKey`, allowing devices built from Xcode to automatically connect without manual typing in the app ← **(DONE)**
- [x] **SEC-04**: Updated `SettingsView.swift` with auto-filling inputs and an `Auto-configured via Secrets.local.plist` visual security shield badge ← **(DONE)**
- [x] **SEC-05**: Updated `Secrets.example.plist` template with `SUPABASE_URL` and `SUPABASE_ANON_KEY` placeholders; verified all 47 tests pass; bumped version to `v1.9.1 (Build 22)` ← **(DONE)**
- [x] **SEC-06**: Integrated user's live Supabase instance (`https://pzfntfhkqibfzraakhyb.supabase.co`) into local git-ignored `Secrets.local.plist`; successfully verified live REST communication (`HTTP 200 OK`) and table readiness across both iPhone and iPad ← **(DONE)**

### Phase 33 — v1.9.2 Cloud Sync Schema Alignment & Secure UI Streamlining
- [x] **SYNC-06**: Diagnosed `HTTP 400 pushing to accounts` caused by column naming discrepancies between Swift DTOs and Supabase PostgreSQL schema (`account_number_last4` vs `last_four`, `initial_balance` vs `starting_balance`) ← **(DONE)**
- [x] **SYNC-07**: Aligned all DTO models in `SyncModels.swift` (`AccountDTO`, `BudgetDTO`, `RecurringRuleDTO`) to match database columns with zero schema mismatch and verified live REST inserts/deletes ← **(DONE)**
- [x] **SYNC-08**: Enhanced `SyncEngine.swift` error diagnostics to log exact PostgreSQL response bodies on upsert failures ← **(DONE)**
- [x] **SYNC-09**: Streamlined `SettingsView.swift` by completely disabling/removing the raw Project URL and Anon Public Key inputs, preventing technical database credentials from being exposed to the user while maintaining seamless background auto-sync via `Secrets.local.plist` ← **(DONE)**
- [x] **SYNC-10**: Added `testAccountAndBudgetDTOSerialization()` in `SyncTests.swift`; verified all 48 tests pass (48/48 passed); guaranteed 100% English UI (0 Chinese characters); bumped version to `v1.9.2 (Build 23)` ← **(DONE)**

---

## 📍 CURRENT STATUS

```
Last Completed : Phase 33 — v1.9.2 Cloud Sync Schema Alignment & Secure UI Streamlining (SYNC-06 to SYNC-10 DONE)
Next Task      : Ready for User Feedback / Next Feature Iteration
Blocking Issues: None (Ready for Production)
```

---

## 🔁 Recovery Protocol (If Context Lost)

1. Open this file → find `CURRENT STATUS` section.
2. Note the **Next Task** value.
3. Re-read source files for the **Last Completed** task.
4. Tell the agent: "Resume from T-XX" or "Continue with the next task."

---

*Last updated: v1.9.2 (Build 23) — Phase 33 Completed & Released — 2026-10-05*
