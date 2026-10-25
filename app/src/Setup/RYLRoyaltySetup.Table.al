namespace PrabinBhusal.RoyaltySample;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Foundation.NoSeries;

table 50100 "RYL Royalty Setup"
{
    Caption = 'Royalty Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "Statement Nos."; Code[20])
        {
            Caption = 'Statement Nos.';
            TableRelation = "No. Series";
            ToolTip = 'Specifies the number series used for royalty statements.';
        }
        field(20; "Accrual Jnl. Template Name"; Code[10])
        {
            Caption = 'Accrual Jnl. Template Name';
            TableRelation = "Gen. Journal Template";
            ToolTip = 'Specifies the general journal template that accrual lines are created in.';

            trigger OnValidate()
            begin
                if "Accrual Jnl. Template Name" <> xRec."Accrual Jnl. Template Name" then
                    "Accrual Jnl. Batch Name" := '';
            end;
        }
        field(21; "Accrual Jnl. Batch Name"; Code[10])
        {
            Caption = 'Accrual Jnl. Batch Name';
            TableRelation = "Gen. Journal Batch".Name where("Journal Template Name" = field("Accrual Jnl. Template Name"));
            ToolTip = 'Specifies the general journal batch that accrual lines are created in. Lines are previewed and posted from the journal, never automatically.';
        }
        field(30; "Royalty Expense Account"; Code[20])
        {
            Caption = 'Royalty Expense Account';
            TableRelation = "G/L Account" where("Account Type" = const(Posting), Blocked = const(false));
            ToolTip = 'Specifies the G/L account debited with the royalty earned in the period.';
        }
        field(31; "Accrued Royalties Account"; Code[20])
        {
            Caption = 'Accrued Royalties Account';
            TableRelation = "G/L Account" where("Account Type" = const(Posting), Blocked = const(false));
            ToolTip = 'Specifies the liability account credited with the amount payable to the licensor.';
        }
        field(32; "Advance Paid Account"; Code[20])
        {
            Caption = 'Advance Paid Account';
            TableRelation = "G/L Account" where("Account Type" = const(Posting), Blocked = const(false));
            ToolTip = 'Specifies the prepayment account credited when royalties are recouped against an advance.';
        }
        field(40; "Last Processed Value Entry No."; Integer)
        {
            Caption = 'Last Processed Value Entry No.';
            MinValue = 0;
            ToolTip = 'Specifies the last value entry the royalty calculation has looked at. The next run starts after this entry. You can set it back to pick up older sales again, for example after mapping an item to a contract. Entries that already have a royalty entry are skipped, so nothing is counted twice.';
        }
        field(50; "Separate Approver Required"; Boolean)
        {
            Caption = 'Separate Approver Required';
            ToolTip = 'Specifies that the user who approves a statement must be different from the user who reviewed it.';
        }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }

    procedure InsertIfMissing()
    begin
        Reset();
        if not Get() then begin
            Init();
            Insert();
        end;
    end;
}
