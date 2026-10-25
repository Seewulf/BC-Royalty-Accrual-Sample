namespace PrabinBhusal.RoyaltySample;

page 50101 "RYL Royalty Contracts"
{
    Caption = 'Royalty Contracts';
    PageType = List;
    SourceTable = "RYL Royalty Contract";
    CardPageId = "RYL Royalty Contract Card";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Contracts)
            {
                field("No."; Rec."No.") { }
                field(Description; Rec.Description) { }
                field("Licensor No."; Rec."Licensor No.") { }
                field("Licensor Name"; Rec."Licensor Name") { }
                field("Royalty Rate %"; Rec."Royalty Rate %") { }
                field("Starting Date"; Rec."Starting Date") { }
                field("Ending Date"; Rec."Ending Date") { }
                field("Advance Amount (LCY)"; Rec."Advance Amount (LCY)") { }
                field("Royalty Earned (LCY)"; Rec."Royalty Earned (LCY)") { }
                field("Recouped Amount (LCY)"; Rec."Recouped Amount (LCY)") { }
                field(Blocked; Rec.Blocked) { }
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
