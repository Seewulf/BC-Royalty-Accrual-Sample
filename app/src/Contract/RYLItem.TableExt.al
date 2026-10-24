namespace PrabinBhusal.RoyaltySample;

using Microsoft.Inventory.Item;

tableextension 50100 "RYL Item" extends Item
{
    fields
    {
        field(50100; "RYL Royalty Contract No."; Code[20])
        {
            Caption = 'Royalty Contract No.';
            DataClassification = CustomerContent;
            TableRelation = "RYL Royalty Contract";
            ToolTip = 'Specifies the royalty contract that sales of this item are calculated under. Blank means no royalty.';
        }
    }
}
