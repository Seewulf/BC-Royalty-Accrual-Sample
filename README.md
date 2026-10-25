# Royalty Accrual Sample for Business Central

A small Business Central extension I wrote to show how I usually handle a finance process end to end.
The example is royalties on licensed merchandise, from posted sales up to the accrual in the G/L.

1. Contract setup - licensor (vendor), royalty rate, start/end date and the advance (minimum guarantee). Each item is linked to a contract.
2. Calculation - a job reads posted sales invoices and credit memos and writes royalty ledger entries (document, item, customer, qty, net sales, rate, royalty).
3. Statements - one statement per contract and period. It picks up the entries, recoups the advance first and goes Draft > Reviewed > Approved. Only users with the approver flag can approve, every status change is logged, and after approval the statement and its entries can't be changed.
4. Accounting - an approved statement gives you general journal lines (expense, advance, accrued payable). Finance checks them with Preview Posting and posts from the journal. Nothing is posted automatically.

Example from the tests: advance 20,000 at 8%. Sales of 150,000 earn 12,000, all of it recouped, nothing to pay.
Another 150,000 earns 12,000 again: 8,000 finishes the advance and 4,000 is payable.

## Some choices I made

- Nothing hooks into sales posting. The calculation reads Value Entries afterwards, from the Job Queue or from the Royalty Setup page, so posting speed is not affected.
- One royalty entry per value entry. Normally that is one per item line; an invoice line that covers several shipments or lots gives several entries, the totals are the same. Item charges and non-item lines are left out.
- No double counting. Each royalty entry keeps its Value Entry No. under a unique key, and setup remembers the last value entry looked at. Running it again creates nothing new.
- The "Last Processed Value Entry No." in setup can be set back. That is how you pick up older sales again, for example after linking an item to a contract later. Entries that already have a royalty entry are skipped.
- Credit memos give negative entries with the credit memo no. on them.
- Recoupment is worked out on the running total for the contract: everything earned so far, capped at the advance. So a period with more returns than sales gives part of the advance back instead of showing a negative payable.
- If a statement is reviewed and then another statement of the same contract is approved first, approval stops and asks you to reopen and review again, so the same advance is never used twice.
- Approved means frozen. Modify, Delete and Rename are blocked in the table triggers (they read the stored record, not xRec). Corrections go into a later period; a sale back-dated into an approved period is picked up by the next statement.
- Review and approve are two steps. Approve needs "Royalty Approver" ticked in User Setup, and with "Separate Approver Required" in setup the reviewer can't approve their own statement.
- The accrual only creates journal lines, it never posts. The batch has to be a plain one (no balancing account, no number series, no VAT copy), so the statement no. ends up as the document no. It stops if lines for the statement are still in the batch or G/L entries with that document no. exist.
- Ledger entries and audit entries are only written through the codeunits (indirect permissions), audit entries can't be changed at all.
- Plain AL, no other dependencies. Standard tables only get two fields (Item, User Setup). Compiles clean with CodeCop, PerTenantExtensionCop and UICop.

## Objects

| Object | What it does |
|---|---|
| Royalty Setup (table 50100, page 50100) | Statement number series, accrual journal template and batch, G/L accounts, last processed value entry, approver option. |
| Royalty Contract (table 50101, pages 50101, 50102) | Contract terms and advance, with earned and recouped totals. |
| Royalty Ledger Entry (table 50102, page 50103) | One line per processed value entry, unique on Value Entry No. |
| Royalty Statement (table 50103, pages 50104, 50105, 50107) | Statement with status, amounts and its entries. |
| Statement Audit Entry (table 50104, page 50106) | Status change log. |
| Statement Status (enum 50100) | Draft, Reviewed, Approved. |
| Royalty Calculation (codeunit 50100) | The calculation. Can be run from the Job Queue. |
| Statement Management (codeunit 50101) | Collect, recalculate, review, reopen, approve. |
| Accrual Journal (codeunit 50102) | Journal lines for an approved statement. |
| Item, User Setup (table and page extensions) | Royalty Contract No. on the item, Royalty Approver on the user. |
| RYL ROYALTY (permission set 50100) | Rights on the sample's own objects. Give it together with a normal finance set (for example D365 BUS FULL ACCESS). |

ID range 50100-50149, tests 50150-50169, prefix RYL.

## Try it

1. Open `app/` in VS Code, create a launch.json for your sandbox (Download Symbols asks for one), download symbols and publish with Ctrl+F5.
2. Royalty Setup: pick a number series for statements, a general journal template and a plain batch, and the three G/L accounts.
3. Royalty Contracts: create a contract (vendor, rate, advance). On the Item Card, under Prices & Sales, set Royalty Contract No.
4. Post a sales invoice for the item, then run Calculate Royalties from Royalty Setup, or add codeunit 50100 to the Job Queue.
5. Royalty Statements: new statement, choose contract and period, Collect Entries, Mark as Reviewed, Approve (tick Royalty Approver on your User Setup first), then Create Accrual Journal Lines and preview and post from the journal.

## Tests

`test/` is a separate app with 31 tests in four codeunits. It only depends on Microsoft's Library Assert, so it runs on a normal online sandbox without the full test toolkit.

- calculation: one entry per invoice, rerun creates nothing, credit memos are negative, unmapped items, blocked contracts and dates outside the contract are skipped, setting the pointer back creates no duplicates and picks up an item mapped later, the Job Queue can run it
- minimum guarantee: the 20,000 / 8% example, drafts don't use the advance, two statements can't both use it, a credit period gives it back
- approval: approver flag, separate approver, approved statements and their entries can't be changed, deleted, renamed or reopened, audit entries for every status change, changing a draft's period releases its entries, late postings go on the next statement
- accrual: balanced lines on the right accounts and date with nothing posted, a batch with a balancing account is refused, no duplicate lines, no accrual on drafts

Run them from the VS Code Test Explorer or with `al runtests` against a BC 29 sandbox. They create their own items, customers and G/L accounts by copying CRONUS records and change Royalty Setup and your User Setup, so use a test company, not one with real data.

## Not in this sample

This is a sample, not a finished product. For a real customer I would also add contract versions with dated rates, territory and channel rules, per-unit and tiered rates, foreign currency contracts, a statement layout per licensor, an exception list for sales that could not be calculated and an import for opening balances. I left those out to keep it small.

If concurrent inventory posting is switched on, value entry numbers can be committed out of order. In that case run the calculation on a schedule rather than during heavy posting, or set the pointer back a little now and then; the unique key makes that safe.

## Requirements

Business Central 29 or later (online or on-prem), AL runtime 18. I tested it on a BC 29.0 online sandbox.

## About

I'm a Business Central developer (AL, and C/AL before that), working mostly on finance processes and NAV to BC upgrades. I put this together as a sample of how I work. If something is unclear or you find a bug, open an issue here.

Prabin

## License

MIT. Copyright (c) 2026 Prabin Bhusal.
