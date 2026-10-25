namespace PrabinBhusal.RoyaltySample;

using Microsoft.Inventory.Item;

pageextension 50100 "RYL Item Card" extends "Item Card"
{
    layout
    {
        addlast("Prices & Sales")
        {
            field("RYL Royalty Contract No."; Rec."RYL Royalty Contract No.")
            {
                ApplicationArea = All;
            }
        }
    }
}
