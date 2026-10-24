namespace PrabinBhusal.RoyaltySample;

using System.Security.User;

pageextension 50101 "RYL User Setup" extends "User Setup"
{
    layout
    {
        addlast(Control1)
        {
            field("RYL Royalty Approver"; Rec."RYL Royalty Approver")
            {
                ApplicationArea = All;
            }
        }
    }
}
