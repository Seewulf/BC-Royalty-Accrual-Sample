namespace PrabinBhusal.RoyaltySample;

page 50100 "RYL Royalty Setup"
{
    Caption = 'Royalty Setup';
    PageType = Card;
    SourceTable = "RYL Royalty Setup";
    ApplicationArea = All;
    UsageCategory = Administration;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Numbering)
            {
                Caption = 'Numbering';
                field("Statement Nos."; Rec."Statement Nos.") { }
            }
            group(Accrual)
            {
                Caption = 'Accrual Journal';
                field("Accrual Jnl. Template Name"; Rec."Accrual Jnl. Template Name") { }
                field("Accrual Jnl. Batch Name"; Rec."Accrual Jnl. Batch Name") { }
                field("Royalty Expense Account"; Rec."Royalty Expense Account") { }
                field("Accrued Royalties Account"; Rec."Accrued Royalties Account") { }
                field("Advance Paid Account"; Rec."Advance Paid Account") { }
            }
            group(Processing)
            {
                Caption = 'Processing';
                field("Last Processed Value Entry No."; Rec."Last Processed Value Entry No.") { }
                field("Separate Approver Required"; Rec."Separate Approver Required") { }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CalculateRoyalties)
            {
                Caption = 'Calculate Royalties';
                Image = Calculate;
                ToolTip = 'Create royalty ledger entries for sales posted since the last run. Safe to run again at any time.';

                trigger OnAction()
                var
                    RoyaltyCalculation: Codeunit "RYL Royalty Calculation";
                begin
                    Message(CreatedMsg, RoyaltyCalculation.ProcessNewSales());
                end;
            }
        }
        area(Promoted)
        {
            actionref(CalculateRoyalties_Promoted; CalculateRoyalties) { }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.InsertIfMissing();
    end;

    var
        CreatedMsg: Label '%1 royalty ledger entries created.', Comment = '%1 = count';
}
