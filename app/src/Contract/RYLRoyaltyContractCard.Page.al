namespace PrabinBhusal.RoyaltySample;

page 50102 "RYL Royalty Contract Card"
{
    Caption = 'Royalty Contract Card';
    PageType = Card;
    SourceTable = "RYL Royalty Contract";
    ApplicationArea = All;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("No."; Rec."No.") { }
                field(Description; Rec.Description) { }
                field("Licensor No."; Rec."Licensor No.") { }
                field("Licensor Name"; Rec."Licensor Name") { }
                field(Blocked; Rec.Blocked) { }
            }
            group(Terms)
            {
                Caption = 'Terms';
                field("Royalty Rate %"; Rec."Royalty Rate %") { }
                field("Starting Date"; Rec."Starting Date") { }
                field("Ending Date"; Rec."Ending Date") { }
                field("Advance Amount (LCY)"; Rec."Advance Amount (LCY)") { }
            }
            group(Balances)
            {
                Caption = 'Balances';
                field("Royalty Earned (LCY)"; Rec."Royalty Earned (LCY)") { }
                field("Recouped Amount (LCY)"; Rec."Recouped Amount (LCY)") { }
                field(UnrecoupedAdvance; Rec.UnrecoupedAdvance())
                {
                    Caption = 'Unrecouped Advance (LCY)';
                    AutoFormatType = 1;
                    ToolTip = 'Specifies the part of the advance not yet offset by approved statements.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(LedgerEntries)
            {
                Caption = 'Royalty Ledger Entries';
                Image = Ledger;
                RunObject = page "RYL Royalty Ledger Entries";
                RunPageLink = "Contract No." = field("No.");
                ToolTip = 'Show the royalty calculated for each posted sales and credit line under this contract.';
            }
            action(Statements)
            {
                Caption = 'Statements';
                Image = Documents;
                RunObject = page "RYL Royalty Statements";
                RunPageLink = "Contract No." = field("No.");
                ToolTip = 'Show the statements issued for this contract.';
            }
        }
        area(Promoted)
        {
            actionref(LedgerEntries_Promoted; LedgerEntries) { }
            actionref(Statements_Promoted; Statements) { }
        }
    }
}
