namespace PrabinBhusal.RoyaltySample;

page 50107 "RYL Royalty Statement Lines"
{
    Caption = 'Entries';
    PageType = ListPart;
    SourceTable = "RYL Royalty Ledger Entry";
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Posting Date"; Rec."Posting Date") { }
                field("Document Type"; Rec."Document Type") { }
                field("Document No."; Rec."Document No.") { }
                field("Item No."; Rec."Item No.") { }
                field("Customer No."; Rec."Customer No.") { }
                field(Quantity; Rec.Quantity) { }
                field("Sales Amount (LCY)"; Rec."Sales Amount (LCY)") { }
                field("Royalty Rate %"; Rec."Royalty Rate %") { }
                field("Royalty Amount (LCY)"; Rec."Royalty Amount (LCY)") { }
            }
        }
    }

    // A new statement has no No. yet. Its link filter is then "Statement No." = '',
    // which would list every entry not on a statement, so show nothing until the No. exists.
    trigger OnFindRecord(Which: Text): Boolean
    var
        StatementNoFilter: Text;
    begin
        Rec.FilterGroup(4);
        StatementNoFilter := Rec.GetFilter("Statement No.");
        Rec.FilterGroup(0);
        if StatementNoFilter = '''''' then
            exit(false);
        exit(Rec.Find(Which));
    end;
}
