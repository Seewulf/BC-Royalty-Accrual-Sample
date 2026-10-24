namespace PrabinBhusal.RoyaltySample;

page 50106 "RYL Statement Audit Entries"
{
    Caption = 'Statement Audit Entries';
    PageType = List;
    SourceTable = "RYL Statement Audit Entry";
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
                field("Statement No."; Rec."Statement No.") { }
                field("Old Status"; Rec."Old Status") { }
                field("New Status"; Rec."New Status") { }
                field("User ID"; Rec."User ID") { }
                field("Changed At"; Rec."Changed At") { }
            }
        }
    }
}
