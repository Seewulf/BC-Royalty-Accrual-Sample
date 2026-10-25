namespace PrabinBhusal.RoyaltySample;

using Microsoft.Foundation.NoSeries;
using Microsoft.Purchases.Vendor;

table 50103 "RYL Royalty Statement"
{
    Caption = 'Royalty Statement';
    DataClassification = CustomerContent;
    DataCaptionFields = "No.", "Contract No.";
    LookupPageId = "RYL Royalty Statements";
    DrillDownPageId = "RYL Royalty Statements";
    Permissions = tabledata "RYL Royalty Ledger Entry" = rm;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            ToolTip = 'Specifies the statement number, taken from the number series in Royalty Setup.';
        }
        field(2; "Contract No."; Code[20])
        {
            Caption = 'Contract No.';
            TableRelation = "RYL Royalty Contract";
            ToolTip = 'Specifies the contract the statement is for.';

            trigger OnValidate()
            var
                RoyaltyContract: Record "RYL Royalty Contract";
            begin
                TestField(Status, Status::Draft);
                if "Contract No." <> xRec."Contract No." then
                    ReleaseEntries();
                if "Contract No." = '' then
                    "Licensor No." := ''
                else begin
                    RoyaltyContract.Get("Contract No.");
                    "Licensor No." := RoyaltyContract."Licensor No.";
                end;
            end;
        }
        field(3; "Licensor No."; Code[20])
        {
            Caption = 'Licensor No.';
            TableRelation = Vendor;
            Editable = false;
            ToolTip = 'Specifies the vendor the statement is addressed to.';
        }
        field(4; "Licensor Name"; Text[100])
        {
            Caption = 'Licensor Name';
            FieldClass = FlowField;
            CalcFormula = lookup(Vendor.Name where("No." = field("Licensor No.")));
            Editable = false;
            ToolTip = 'Specifies the name of the licensor.';
        }
        field(10; "Period Start"; Date)
        {
            Caption = 'Period Start';
            ToolTip = 'Specifies the first day of the statement period. Entries from earlier periods that are not on any statement yet, for example late postings, are also picked up.';

            trigger OnValidate()
            begin
                TestField(Status, Status::Draft);
                if "Period Start" <> xRec."Period Start" then
                    ReleaseEntries();
            end;
        }
        field(11; "Period End"; Date)
        {
            Caption = 'Period End';
            ToolTip = 'Specifies the last posting date included in the statement. Accrual lines use this as posting date.';

            trigger OnValidate()
            begin
                TestField(Status, Status::Draft);
                if "Period End" <> xRec."Period End" then
                    ReleaseEntries();
            end;
        }
        field(20; Status; Enum "RYL Statement Status")
        {
            Caption = 'Status';
            Editable = false;
            ToolTip = 'Specifies where the statement is in the Draft, Reviewed, Approved flow. Approved statements are frozen.';
        }
        field(30; "Earned Amount (LCY)"; Decimal)
        {
            Caption = 'Earned Amount (LCY)';
            AutoFormatType = 1;
            Editable = false;
            ToolTip = 'Specifies the royalty earned on the entries on this statement.';
        }
        field(31; "Recouped Amount (LCY)"; Decimal)
        {
            Caption = 'Recouped Amount (LCY)';
            AutoFormatType = 1;
            Editable = false;
            ToolTip = 'Specifies the part of the earned royalty offset against the advance. It is negative when a credit period gives part of the advance back.';
        }
        field(32; "Payable Amount (LCY)"; Decimal)
        {
            Caption = 'Payable Amount (LCY)';
            AutoFormatType = 1;
            Editable = false;
            ToolTip = 'Specifies the royalty to pay on top of the advance: earned minus recouped.';
        }
        field(40; "No. of Entries"; Integer)
        {
            Caption = 'No. of Entries';
            FieldClass = FlowField;
            CalcFormula = count("RYL Royalty Ledger Entry" where("Statement No." = field("No.")));
            Editable = false;
            ToolTip = 'Specifies how many royalty ledger entries the statement includes.';
        }
        field(50; "Reviewed By"; Code[50])
        {
            Caption = 'Reviewed By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
            ToolTip = 'Specifies the user who marked the statement as reviewed.';
        }
        field(51; "Approved By"; Code[50])
        {
            Caption = 'Approved By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
            ToolTip = 'Specifies the user who approved the statement.';
        }
        field(52; "Approved At"; DateTime)
        {
            Caption = 'Approved At';
            Editable = false;
            ToolTip = 'Specifies when the statement was approved and frozen.';
        }
        field(60; "No. Series"; Code[20])
        {
            Caption = 'No. Series';
            TableRelation = "No. Series";
            Editable = false;
            ToolTip = 'Specifies the number series the statement number was taken from.';
        }
    }

    keys
    {
        key(PK; "No.") { Clustered = true; }
        key(Contract; "Contract No.", Status) { SumIndexFields = "Earned Amount (LCY)", "Recouped Amount (LCY)"; }
    }

    trigger OnInsert()
    var
        RoyaltySetup: Record "RYL Royalty Setup";
        NoSeries: Codeunit "No. Series";
    begin
        if "No." = '' then begin
            RoyaltySetup.Get();
            RoyaltySetup.TestField("Statement Nos.");
            "No. Series" := RoyaltySetup."Statement Nos.";
            "No." := NoSeries.GetNextNo("No. Series", WorkDate());
        end;
    end;

    trigger OnModify()
    var
        StoredStatement: Record "RYL Royalty Statement";
    begin
        // don't trust xRec here, read the db version
        if StoredStatement.Get("No.") then
            if StoredStatement.Status = StoredStatement.Status::Approved then
                Error(FrozenErr, "No.");
    end;

    trigger OnDelete()
    var
        StoredStatement: Record "RYL Royalty Statement";
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
    begin
        if StoredStatement.Get("No.") then
            StoredStatement.TestField(Status, Status::Draft);
        TestField(Status, Status::Draft);
        RoyaltyLedgerEntry.SetRange("Statement No.", "No.");
        RoyaltyLedgerEntry.ModifyAll("Statement No.", '', true);
    end;

    trigger OnRename()
    begin
        // the statement no. is the document no. on the G/L entries
        Error(RenameErr);
    end;

    local procedure ReleaseEntries()
    var
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
    begin
        if "No." = '' then
            exit;
        RoyaltyLedgerEntry.SetRange("Statement No.", "No.");
        if RoyaltyLedgerEntry.IsEmpty() then
            exit;
        RoyaltyLedgerEntry.ModifyAll("Statement No.", '', true);
        "Earned Amount (LCY)" := 0;
        "Recouped Amount (LCY)" := 0;
        "Payable Amount (LCY)" := 0;
    end;

    var
        FrozenErr: Label 'Statement %1 is approved and cannot be changed.', Comment = '%1 = statement no.';
        RenameErr: Label 'Royalty statements cannot be renamed.';
}
