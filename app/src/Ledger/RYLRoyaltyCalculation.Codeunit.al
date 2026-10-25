namespace PrabinBhusal.RoyaltySample;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using System.Threading;

// Royalty calculation from value entries. Run from job queue or the setup page.
codeunit 50100 "RYL Royalty Calculation"
{
    // the job queue passes its own entry in, so TableNo has to be Job Queue Entry
    TableNo = "Job Queue Entry";
    Permissions = tabledata "RYL Royalty Ledger Entry" = ri;

    trigger OnRun()
    begin
        ProcessNewSales();
    end;

    procedure ProcessNewSales() EntriesCreated: Integer
    var
        RoyaltySetup: Record "RYL Royalty Setup";
        ValueEntry: Record "Value Entry";
        LastEntryNo: Integer;
    begin
        RoyaltySetup.LockTable();
        RoyaltySetup.InsertIfMissing();
        LastEntryNo := RoyaltySetup."Last Processed Value Entry No.";

        ValueEntry.ReadIsolation := IsolationLevel::ReadCommitted;
        ValueEntry.SetCurrentKey("Entry No.");
        ValueEntry.SetFilter("Entry No.", '>%1', LastEntryNo);
        ValueEntry.SetRange("Item Ledger Entry Type", ValueEntry."Item Ledger Entry Type"::Sale);
        ValueEntry.SetFilter("Document Type", '%1|%2', ValueEntry."Document Type"::"Sales Invoice", ValueEntry."Document Type"::"Sales Credit Memo");
        ValueEntry.SetRange("Item Charge No.", '');
        if ValueEntry.FindSet() then
            repeat
                if ProcessValueEntry(ValueEntry) then
                    EntriesCreated += 1;
                LastEntryNo := ValueEntry."Entry No.";
            until ValueEntry.Next() = 0;

        if LastEntryNo <> RoyaltySetup."Last Processed Value Entry No." then begin
            RoyaltySetup."Last Processed Value Entry No." := LastEntryNo;
            RoyaltySetup.Modify();
        end;
    end;

    local procedure ProcessValueEntry(ValueEntry: Record "Value Entry"): Boolean
    var
        Item: Record Item;
        RoyaltyContract: Record "RYL Royalty Contract";
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
    begin
        if ValueEntry."Sales Amount (Actual)" = 0 then
            exit(false);
        if not Item.Get(ValueEntry."Item No.") then
            exit(false);
        if Item."RYL Royalty Contract No." = '' then
            exit(false);
        if not RoyaltyContract.Get(Item."RYL Royalty Contract No.") then
            exit(false);
        if not ContractCovers(RoyaltyContract, ValueEntry."Posting Date") then
            exit(false);

        // already done, for example after the pointer was set back (unique key on value entry no.)
        RoyaltyLedgerEntry.SetRange("Value Entry No.", ValueEntry."Entry No.");
        if not RoyaltyLedgerEntry.IsEmpty() then
            exit(false);

        RoyaltyLedgerEntry.Init();
        RoyaltyLedgerEntry."Entry No." := 0;
        RoyaltyLedgerEntry."Contract No." := RoyaltyContract."No.";
        RoyaltyLedgerEntry."Value Entry No." := ValueEntry."Entry No.";
        RoyaltyLedgerEntry."Document Type" := ValueEntry."Document Type";
        RoyaltyLedgerEntry."Document No." := ValueEntry."Document No.";
        RoyaltyLedgerEntry."Document Line No." := ValueEntry."Document Line No.";
        RoyaltyLedgerEntry."Posting Date" := ValueEntry."Posting Date";
        RoyaltyLedgerEntry."Item No." := ValueEntry."Item No.";
        RoyaltyLedgerEntry."Customer No." := ValueEntry."Source No.";
        RoyaltyLedgerEntry.Quantity := -ValueEntry."Invoiced Quantity";
        RoyaltyLedgerEntry."Sales Amount (LCY)" := ValueEntry."Sales Amount (Actual)";
        RoyaltyLedgerEntry."Royalty Rate %" := RoyaltyContract."Royalty Rate %";
        RoyaltyLedgerEntry."Royalty Amount (LCY)" := RoundAmount(ValueEntry."Sales Amount (Actual)" * RoyaltyContract."Royalty Rate %" / 100);
        RoyaltyLedgerEntry."Created At" := CurrentDateTime();
        RoyaltyLedgerEntry.Insert(true);
        exit(true);
    end;

    local procedure ContractCovers(RoyaltyContract: Record "RYL Royalty Contract"; PostingDate: Date): Boolean
    begin
        if RoyaltyContract.Blocked then
            exit(false);
        if (RoyaltyContract."Starting Date" <> 0D) and (PostingDate < RoyaltyContract."Starting Date") then
            exit(false);
        if (RoyaltyContract."Ending Date" <> 0D) and (PostingDate > RoyaltyContract."Ending Date") then
            exit(false);
        exit(true);
    end;

    procedure RoundAmount(Amount: Decimal): Decimal
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
    begin
        GeneralLedgerSetup.GetRecordOnce();
        exit(Round(Amount, GeneralLedgerSetup."Amount Rounding Precision"));
    end;
}
