namespace PrabinBhusal.RoyaltySample;

page 50104 "RYL Royalty Statements"
{
    Caption = 'Royalty Statements';
    PageType = List;
    SourceTable = "RYL Royalty Statement";
    CardPageId = "RYL Royalty Statement";
    ApplicationArea = All;
    UsageCategory = Documents;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Statements)
            {
                field("No."; Rec."No.") { }
                field("Contract No."; Rec."Contract No.") { }
                field("Licensor No."; Rec."Licensor No.") { }
                field("Licensor Name"; Rec."Licensor Name") { }
                field("Period Start"; Rec."Period Start") { }
                field("Period End"; Rec."Period End") { }
                field(Status; Rec.Status) { }
                field("Earned Amount (LCY)"; Rec."Earned Amount (LCY)") { }
                field("Recouped Amount (LCY)"; Rec."Recouped Amount (LCY)") { }
                field("Payable Amount (LCY)"; Rec."Payable Amount (LCY)") { }
            }
        }
    }
}
