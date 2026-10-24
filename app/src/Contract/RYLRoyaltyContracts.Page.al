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
}
