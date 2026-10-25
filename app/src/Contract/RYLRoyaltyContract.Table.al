namespace PrabinBhusal.RoyaltySample;

using Microsoft.Purchases.Vendor;

table 50101 "RYL Royalty Contract"
{
    Caption = 'Royalty Contract';
    DataClassification = CustomerContent;
    DataCaptionFields = "No.", Description;
    LookupPageId = "RYL Royalty Contracts";
    DrillDownPageId = "RYL Royalty Contracts";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            NotBlank = true;
            ToolTip = 'Specifies the contract code, for example the licensor and year.';
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            ToolTip = 'Specifies what the contract covers.';
        }
        field(10; "Licensor No."; Code[20])
        {
            Caption = 'Licensor No.';
            TableRelation = Vendor;
            ToolTip = 'Specifies the vendor that receives the royalty.';
        }
        field(11; "Licensor Name"; Text[100])
        {
            Caption = 'Licensor Name';
            FieldClass = FlowField;
            CalcFormula = lookup(Vendor.Name where("No." = field("Licensor No.")));
            Editable = false;
            ToolTip = 'Specifies the name of the licensor.';
        }
        field(20; "Royalty Rate %"; Decimal)
        {
            Caption = 'Royalty Rate %';
            DecimalPlaces = 0 : 2;
            MinValue = 0;
            MaxValue = 100;
            ToolTip = 'Specifies the percentage of the net sales amount that is owed as royalty. A change applies to sales calculated after the change; existing entries keep the rate they were calculated with.';
        }
        field(21; "Starting Date"; Date)
        {
            Caption = 'Starting Date';
            ToolTip = 'Specifies the first posting date that the contract applies to.';

            trigger OnValidate()
            begin
                CheckDates();
            end;
        }
        field(22; "Ending Date"; Date)
        {
            Caption = 'Ending Date';
            ToolTip = 'Specifies the last posting date that the contract applies to. Leave blank for no end date.';

            trigger OnValidate()
            begin
                CheckDates();
            end;
        }
        field(30; "Advance Amount (LCY)"; Decimal)
        {
            Caption = 'Advance Amount (LCY)';
            AutoFormatType = 1;
            MinValue = 0;
            ToolTip = 'Specifies the recoupable advance (minimum guarantee) paid to the licensor. Royalties earned are offset against it before anything becomes payable.';

            trigger OnValidate()
            begin
                CalcFields("Recouped Amount (LCY)");
                if "Advance Amount (LCY)" < "Recouped Amount (LCY)" then
                    Error(AdvanceBelowRecoupedErr, "Recouped Amount (LCY)");
            end;
        }
        field(40; Blocked; Boolean)
        {
            Caption = 'Blocked';
            ToolTip = 'Specifies that no new royalty entries are created for this contract.';
        }
#pragma warning disable AA0232 // key "Contract" on the ledger entry already has this sum
        field(100; "Royalty Earned (LCY)"; Decimal)
        {
            Caption = 'Royalty Earned (LCY)';
            AutoFormatType = 1;
            FieldClass = FlowField;
            CalcFormula = sum("RYL Royalty Ledger Entry"."Royalty Amount (LCY)" where("Contract No." = field("No.")));
            Editable = false;
            ToolTip = 'Specifies the royalty calculated from all posted sales and credits under this contract.';
        }
#pragma warning restore AA0232
        field(101; "Recouped Amount (LCY)"; Decimal)
        {
            Caption = 'Recouped Amount (LCY)';
            AutoFormatType = 1;
            FieldClass = FlowField;
            CalcFormula = sum("RYL Royalty Statement"."Recouped Amount (LCY)" where("Contract No." = field("No."), Status = const(Approved)));
            Editable = false;
            ToolTip = 'Specifies how much of the advance has been used up by approved statements.';
        }
    }

    keys
    {
        key(PK; "No.") { Clustered = true; }
    }

    trigger OnDelete()
    var
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
    begin
        RoyaltyLedgerEntry.SetRange("Contract No.", "No.");
        if not RoyaltyLedgerEntry.IsEmpty() then
            Error(HasEntriesErr, "No.");
    end;

    procedure UnrecoupedAdvance(): Decimal
    begin
        CalcFields("Recouped Amount (LCY)");
        exit("Advance Amount (LCY)" - "Recouped Amount (LCY)");
    end;

    local procedure CheckDates()
    begin
        if ("Starting Date" <> 0D) and ("Ending Date" <> 0D) and ("Starting Date" > "Ending Date") then
            Error(DateOrderErr);
    end;

    var
        HasEntriesErr: Label 'Contract %1 has royalty ledger entries and cannot be deleted.', Comment = '%1 = contract no.';
        AdvanceBelowRecoupedErr: Label 'The advance cannot be lower than the %1 already recouped on approved statements.', Comment = '%1 = recouped amount';
        DateOrderErr: Label 'The starting date must be before the ending date.';
}
