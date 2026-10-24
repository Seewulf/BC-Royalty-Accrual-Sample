namespace PrabinBhusal.RoyaltySample;

using System.Security.User;

tableextension 50101 "RYL User Setup" extends "User Setup"
{
    fields
    {
        field(50100; "RYL Royalty Approver"; Boolean)
        {
            Caption = 'Royalty Approver';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies that the user may approve royalty statements.';
        }
    }
}
