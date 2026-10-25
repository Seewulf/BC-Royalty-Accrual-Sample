namespace PrabinBhusal.RoyaltySample;

table 50104 "RYL Statement Audit Entry"
{
    Caption = 'Statement Audit Entry';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            ToolTip = 'Specifies the number of the entry.';
        }
        field(2; "Statement No."; Code[20])
        {
            Caption = 'Statement No.';
            TableRelation = "RYL Royalty Statement";
            ToolTip = 'Specifies the statement that changed.';
        }
        field(10; "Old Status"; Enum "RYL Statement Status")
        {
            Caption = 'Old Status';
            ToolTip = 'Specifies the status before the change.';
        }
        field(11; "New Status"; Enum "RYL Statement Status")
        {
            Caption = 'New Status';
            ToolTip = 'Specifies the status after the change.';
        }
        field(20; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
            ToolTip = 'Specifies who made the change.';
        }
        field(21; "Changed At"; DateTime)
        {
            Caption = 'Changed At';
            ToolTip = 'Specifies when the change was made.';
        }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(Statement; "Statement No.") { }
    }

    // audit rows are only ever added
    trigger OnModify()
    begin
        Error(ReadOnlyErr);
    end;

    trigger OnDelete()
    begin
        Error(ReadOnlyErr);
    end;

    trigger OnRename()
    begin
        Error(ReadOnlyErr);
    end;

    var
        ReadOnlyErr: Label 'Statement audit entries cannot be changed or deleted.';
}
