# Royalty Accrual Sample for Business Central

A small, complete Business Central extension (AL) that shows how I build financial processing that has to be
**traceable, repeatable and safe to upgrade**. It takes a licensed-merchandise royalty process from posted sales
through to accounting:

1. **Contract setup** – licensor (vendor), royalty rate, validity dates, recoupable advance (minimum guarantee). Items are mapped to a contract.
2. **Calculation** – a scheduled job turns posted sales invoices and credit memos into a **royalty ledger**: one entry per posted line, with document, item, customer, quantity, net sales, the rate used and the royalty amount.
3. **Statements** – a statement per contract and period collects the entries, applies **minimum-guarantee recoupment** and moves through **Draft → Reviewed → Approved**. Approval is restricted to flagged users, every status change is audited, and an approved statement is frozen.
4. **Accounting** – an approved statement creates balanced **general journal lines** (expense, advance recoupment, accrued payable) that Finance previews and posts from the journal. Nothing posts automatically.

The worked example in the tests: advance 20,000, 8% royalty. Sales of 150,000 earn 12,000, all recouped, nothing payable.
Another 150,000 earns 12,000, of which 8,000 finishes the advance and 4,000 becomes payable.

## Design decisions

| Concern | How it is handled |
|---|---|
| Posting performance | Nothing runs inside sales posting. There are no event subscribers on the posting codeunits. The calculation reads **Value Entries** afterwards, on a Job Queue schedule or on demand. |
| No double counting | Each royalty entry stores the **Value Entry No.** it came from, under a **unique key**. The calculation skips anything already processed, and a setup pointer makes each run start where the last one stopped. Running it twice is a no-op (covered by a test). |
| Credits and returns | Credit memos produce negative entries in the period they post. The original document reference stays on each entry. |
| Frozen periods | Approved statements and their entries reject any `Modify` or `Delete` at table level, not just in the UI. Corrections are new entries in a later period. |
| Separation of duties | Review and approval are separate steps. Approval requires the **Royalty Approver** flag in User Setup. |
| Audit trail | Every status change writes who, when, from and to. Each ledger entry stores the rate in force and when it was created. |
| Accounting control | Journal lines are created, never posted. The standard journal **Preview Posting** applies. A statement cannot be accrued twice: existing journal lines or G/L entries with its document number block a repeat. |
| Minimum guarantee | Recoupment is calculated from the contract's advance minus what **approved** statements have already recouped. Draft statements show the effect without consuming the advance. |
| Upgrade safety | Standard AL only, no third-party dependencies, no base-application object modifications beyond two added fields (Item, User Setup). Namespaces, CodeCop, PerTenantExtensionCop and UICop clean. |

## Objects

| Object | Purpose |
|---|---|
| `RYL Royalty Setup` (table/page) | Statement number series, accrual journal batch, G/L accounts, processing pointer. |
| `RYL Royalty Contract` (table, list, card) | Contract terms and advance; FlowFields for earned and recouped. |
| `RYL Royalty Ledger Entry` (table, list) | One line per processed value entry. Unique on Value Entry No. |
| `RYL Royalty Statement` (table, list, card) | Period statement with Draft/Reviewed/Approved and the three amounts. |
| `RYL Statement Audit Entry` (table, list) | Status-change log. |
| `RYL Royalty Calculation` (codeunit 50100) | Idempotent calculation. Schedule it as a Job Queue entry. |
| `RYL Statement Management` (codeunit 50101) | Collect entries, recalculate, review, reopen, approve. |
| `RYL Accrual Journal` (codeunit 50102) | Create journal lines for an approved statement and open the journal. |
| `RYL ROYALTY` (permission set) | Full access to the sample's objects. |

ID range 50100–50149 (tests 50150–50169). Prefix `RYL`.

## Try it

1. Open `app/` in VS Code, point `.vscode/launch.json` at your sandbox and publish (`Ctrl+F5`).
2. **Royalty Setup**: pick a number series for statements, a general journal batch and three G/L accounts.
3. **Royalty Contracts**: create a contract (vendor, rate, advance). On an **Item Card**, set *Royalty Contract No.*.
4. Post a sales invoice for the item, then run **Calculate Royalties** from Royalty Setup (or schedule codeunit 50100 in the Job Queue).
5. **Royalty Statements**: new statement, choose the contract and period, **Collect Entries**, **Mark as Reviewed**, **Approve** (needs the *Royalty Approver* flag on your User Setup), then **Create Accrual Journal Lines** and preview-post from the journal.

## Tests

`test/` is a separate app with 16 tests over four codeunits. It depends only on Microsoft's `Library Assert`, which every online sandbox has, so the tests run without installing the test toolkit:

- calculation: one entry per invoice, rerun is a no-op, credit memos are negative, unmapped items are skipped
- minimum guarantee: the 20,000 / 8% example above, and that drafts do not consume the advance
- approval: non-approvers are refused, approvers succeed, approved statements and their entries reject modify and delete, every status change is audited, deleting a draft releases its entries
- accrual: balanced journal lines on the right accounts and posting date, no duplicate creation, no accrual on drafts

Run them from the VS Code Test Explorer against a sandbox (BC 28 or later) or with `al runtests`.

## What this is not

It is a sample of engineering approach, not a product. A real implementation adds contract versions with effective-dated rates,
territory and channel rules, per-unit and tiered rates, multi-currency contracts with stored FX, intercompany handling,
statement layouts per licensor, an exception queue, forecasting and opening-balance import. The structure here is the base those sit on.

## Requirements

Business Central 29 or later (online or on-premises), AL runtime 18. Built against the 29.0 symbols and verified on a Business Central 29 online sandbox, so it is ready for the 29.1 update.

## License

MIT. Copyright (c) 2026 Prabin Bhusal.
