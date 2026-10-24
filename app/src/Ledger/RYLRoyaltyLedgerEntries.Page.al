namespace PrabinBhusal.RoyaltySample;

page 50103 "RYL Royalty Ledger Entries"
{
    Caption = 'Royalty Ledger Entries';
    PageType = List;
    SourceTable = "RYL Royalty Ledger Entry";
    ApplicationArea = All;
    UsageCategory = History;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Entry No."; Rec."Entry No.") { }
                field("Contract No."; Rec."Contract No.") { }
                field("Posting Date"; Rec."Posting Date") { }
                field("Document Type"; Rec."Document Type") { }
                field("Document No."; Rec."Document No.") { }
                field("Document Line No."; Rec."Document Line No.") { }
                field("Item No."; Rec."Item No.") { }
                field("Customer No."; Rec."Customer No.") { }
                field(Quantity; Rec.Quantity) { }
                field("Sales Amount (LCY)"; Rec."Sales Amount (LCY)") { }
                field("Royalty Rate %"; Rec."Royalty Rate %") { }
                field("Royalty Amount (LCY)"; Rec."Royalty Amount (LCY)") { }
                field("Statement No."; Rec."Statement No.") { }
                field("Value Entry No."; Rec."Value Entry No.") { }
                field("Created At"; Rec."Created At") { }
            }
        }
    }
}
