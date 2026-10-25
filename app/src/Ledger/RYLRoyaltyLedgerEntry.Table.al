namespace PrabinBhusal.RoyaltySample;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Sales.Customer;

table 50102 "RYL Royalty Ledger Entry"
{
    Caption = 'Royalty Ledger Entry';
    DataClassification = CustomerContent;
    LookupPageId = "RYL Royalty Ledger Entries";
    DrillDownPageId = "RYL Royalty Ledger Entries";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            ToolTip = 'Specifies the number of the entry.';
        }
        field(2; "Contract No."; Code[20])
        {
            Caption = 'Contract No.';
            TableRelation = "RYL Royalty Contract";
            ToolTip = 'Specifies the contract the royalty was calculated under.';
        }
        field(3; "Value Entry No."; Integer)
        {
            Caption = 'Value Entry No.';
            TableRelation = "Value Entry";
            ToolTip = 'Specifies the posted value entry this royalty was calculated from. Each value entry is processed once.';
        }
        field(10; "Document Type"; Enum "Item Ledger Document Type")
        {
            Caption = 'Document Type';
            ToolTip = 'Specifies whether the source is a posted sales invoice or a posted sales credit memo.';
        }
        field(11; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            ToolTip = 'Specifies the posted document number.';
        }
        field(12; "Document Line No."; Integer)
        {
            Caption = 'Document Line No.';
            ToolTip = 'Specifies the line number on the posted document.';
        }
        field(13; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
            ToolTip = 'Specifies the posting date of the source document.';
        }
        field(14; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
            ToolTip = 'Specifies the item that was sold or credited.';
        }
        field(15; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            TableRelation = Customer;
            ToolTip = 'Specifies the customer on the source document.';
        }
        field(20; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
            ToolTip = 'Specifies the quantity invoiced. Credits are negative.';
        }
        field(21; "Sales Amount (LCY)"; Decimal)
        {
            Caption = 'Sales Amount (LCY)';
            AutoFormatType = 1;
            ToolTip = 'Specifies the net sales amount the royalty rate was applied to, in local currency.';
        }
        field(22; "Royalty Rate %"; Decimal)
        {
            Caption = 'Royalty Rate %';
            DecimalPlaces = 0 : 2;
            ToolTip = 'Specifies the contract rate used when the entry was calculated.';
        }
        field(23; "Royalty Amount (LCY)"; Decimal)
        {
            Caption = 'Royalty Amount (LCY)';
            AutoFormatType = 1;
            ToolTip = 'Specifies the royalty owed for this line. Credits are negative.';
        }
        field(30; "Statement No."; Code[20])
        {
            Caption = 'Statement No.';
            TableRelation = "RYL Royalty Statement";
            ToolTip = 'Specifies the statement this entry has been included in. Blank until a statement collects it.';
        }
        field(40; "Created At"; DateTime)
        {
            Caption = 'Created At';
            ToolTip = 'Specifies when the calculation created this entry.';
        }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(ValueEntry; "Value Entry No.") { Unique = true; }
        key(Contract; "Contract No.") { SumIndexFields = "Royalty Amount (LCY)"; }
        key(ContractPeriod; "Contract No.", "Posting Date", "Statement No.") { }
        key(Statement; "Statement No.") { SumIndexFields = "Royalty Amount (LCY)", "Sales Amount (LCY)", Quantity; }
    }

    trigger OnModify()
    var
        StoredEntry: Record "RYL Royalty Ledger Entry";
    begin
        if StoredEntry.Get("Entry No.") then
            TestNotFrozen(StoredEntry."Statement No.");
        TestNotFrozen("Statement No.");
    end;

    trigger OnDelete()
    var
        StoredEntry: Record "RYL Royalty Ledger Entry";
    begin
        if StoredEntry.Get("Entry No.") then
            TestNotFrozen(StoredEntry."Statement No.");
        TestNotFrozen("Statement No.");
    end;

    trigger OnRename()
    begin
        Error(RenameErr);
    end;

    local procedure TestNotFrozen(StatementNo: Code[20])
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        if StatementNo = '' then
            exit;
        if not RoyaltyStatement.Get(StatementNo) then
            exit;
        if RoyaltyStatement.Status = RoyaltyStatement.Status::Approved then
            Error(FrozenErr, "Entry No.", StatementNo);
    end;

    var
        RenameErr: Label 'Royalty ledger entries cannot be renamed.';
        FrozenErr: Label 'Royalty ledger entry %1 belongs to approved statement %2 and cannot be changed. Post a correction in a later period instead.', Comment = '%1 = entry no., %2 = statement no.';
}
