namespace PrabinBhusal.RoyaltySample;

page 50105 "RYL Royalty Statement Card"
{
    Caption = 'Royalty Statement';
    PageType = Document;
    SourceTable = "RYL Royalty Statement";
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("No."; Rec."No.") { }
                field("Contract No."; Rec."Contract No.") { }
                field("Licensor No."; Rec."Licensor No.") { }
                field("Period Start"; Rec."Period Start") { }
                field("Period End"; Rec."Period End") { }
                field(Status; Rec.Status) { }
                field("No. of Entries"; Rec."No. of Entries") { }
            }
            group(Amounts)
            {
                Caption = 'Amounts';
                field("Earned Amount (LCY)"; Rec."Earned Amount (LCY)") { }
                field("Recouped Amount (LCY)"; Rec."Recouped Amount (LCY)") { }
                field("Payable Amount (LCY)"; Rec."Payable Amount (LCY)") { }
            }
            group(Approval)
            {
                Caption = 'Approval';
                field("Reviewed By"; Rec."Reviewed By") { }
                field("Approved By"; Rec."Approved By") { }
                field("Approved At"; Rec."Approved At") { }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CollectEntries)
            {
                Caption = 'Collect Entries';
                Image = GetEntries;
                Enabled = Rec.Status = Rec.Status::Draft;
                ToolTip = 'Attach the royalty ledger entries of the contract in the period that are not yet on a statement, and recalculate the totals.';

                trigger OnAction()
                begin
                    Message(CollectedMsg, StatementManagement.CollectEntries(Rec));
                end;
            }
            action(Review)
            {
                Caption = 'Mark as Reviewed';
                Image = Approve;
                Enabled = Rec.Status = Rec.Status::Draft;
                ToolTip = 'Confirm the figures have been checked. The statement can still be reopened.';

                trigger OnAction()
                begin
                    StatementManagement.Review(Rec);
                end;
            }
            action(Reopen)
            {
                Caption = 'Reopen';
                Image = ReOpen;
                Enabled = Rec.Status = Rec.Status::Reviewed;
                ToolTip = 'Send the statement back to Draft so entries can be collected again.';

                trigger OnAction()
                begin
                    StatementManagement.Reopen(Rec);
                end;
            }
            action(Approve)
            {
                Caption = 'Approve';
                Image = Confirm;
                Enabled = Rec.Status = Rec.Status::Reviewed;
                ToolTip = 'Approve and freeze the statement. Requires the Royalty Approver flag in User Setup.';

                trigger OnAction()
                begin
                    if Confirm(ApproveQst, false, Rec."No.") then
                        StatementManagement.Approve(Rec);
                end;
            }
            action(CreateAccrual)
            {
                Caption = 'Create Accrual Journal Lines';
                Image = Journal;
                Enabled = Rec.Status = Rec.Status::Approved;
                ToolTip = 'Create the expense, recoupment and payable lines in the accrual journal batch. Preview and post them from the journal.';

                trigger OnAction()
                var
                    AccrualJournal: Codeunit "RYL Accrual Journal";
                begin
                    Message(LinesMsg, AccrualJournal.CreateLines(Rec));
                    AccrualJournal.OpenJournal();
                end;
            }
        }
        area(Navigation)
        {
            action(Entries)
            {
                Caption = 'Royalty Ledger Entries';
                Image = Ledger;
                RunObject = page "RYL Royalty Ledger Entries";
                RunPageLink = "Statement No." = field("No.");
                ToolTip = 'Show the entries included in this statement.';
            }
            action(AuditEntries)
            {
                Caption = 'Audit Entries';
                Image = History;
                RunObject = page "RYL Statement Audit Entries";
                RunPageLink = "Statement No." = field("No.");
                ToolTip = 'Show who changed the status of this statement and when.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(CollectEntries_Promoted; CollectEntries) { }
                actionref(Review_Promoted; Review) { }
                actionref(Approve_Promoted; Approve) { }
                actionref(Reopen_Promoted; Reopen) { }
                actionref(CreateAccrual_Promoted; CreateAccrual) { }
            }
            group(Category_Navigate)
            {
                Caption = 'Statement';
                actionref(Entries_Promoted; Entries) { }
                actionref(AuditEntries_Promoted; AuditEntries) { }
            }
        }
    }

    var
        StatementManagement: Codeunit "RYL Statement Management";
        CollectedMsg: Label '%1 entries collected.', Comment = '%1 = count';
        LinesMsg: Label '%1 journal lines created. Preview and post them from the journal.', Comment = '%1 = count';
        ApproveQst: Label 'Approve statement %1? It will be frozen and its entries can no longer be changed.', Comment = '%1 = statement no.';
}
