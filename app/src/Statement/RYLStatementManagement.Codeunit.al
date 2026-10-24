namespace PrabinBhusal.RoyaltySample;

using System.Security.User;

// Statement handling: collect entries, MG recoupment, draft -> reviewed -> approved.
codeunit 50101 "RYL Statement Management"
{
    procedure CollectEntries(var RoyaltyStatement: Record "RYL Royalty Statement") EntriesAdded: Integer
    var
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
    begin
        RoyaltyStatement.TestField(Status, RoyaltyStatement.Status::Draft);
        RoyaltyStatement.TestField("Contract No.");
        RoyaltyStatement.TestField("Period Start");
        RoyaltyStatement.TestField("Period End");
        if RoyaltyStatement."Period End" < RoyaltyStatement."Period Start" then
            RoyaltyStatement.FieldError("Period End", PeriodErr);

        RoyaltyLedgerEntry.SetCurrentKey("Contract No.", "Posting Date", "Statement No.");
        RoyaltyLedgerEntry.SetRange("Contract No.", RoyaltyStatement."Contract No.");
        RoyaltyLedgerEntry.SetRange("Posting Date", RoyaltyStatement."Period Start", RoyaltyStatement."Period End");
        RoyaltyLedgerEntry.SetRange("Statement No.", '');
        if RoyaltyLedgerEntry.FindSet(true) then
            repeat
                RoyaltyLedgerEntry."Statement No." := RoyaltyStatement."No.";
                RoyaltyLedgerEntry.Modify(true);
                EntriesAdded += 1;
            until RoyaltyLedgerEntry.Next() = 0;

        Recalculate(RoyaltyStatement);
    end;

    procedure Recalculate(var RoyaltyStatement: Record "RYL Royalty Statement")
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
        Unrecouped: Decimal;
    begin
        RoyaltyStatement.TestField(Status, RoyaltyStatement.Status::Draft);
        RoyaltyContract.Get(RoyaltyStatement."Contract No.");

        RoyaltyLedgerEntry.SetCurrentKey("Statement No.");
        RoyaltyLedgerEntry.SetRange("Statement No.", RoyaltyStatement."No.");
        RoyaltyLedgerEntry.CalcSums("Royalty Amount (LCY)");
        RoyaltyStatement."Earned Amount (LCY)" := RoyaltyLedgerEntry."Royalty Amount (LCY)";

        // recoup against what is left of the advance, only approved statements count
        Unrecouped := RoyaltyContract.UnrecoupedAdvance();
        RoyaltyStatement."Recouped Amount (LCY)" := 0;
        if (RoyaltyStatement."Earned Amount (LCY)" > 0) and (Unrecouped > 0) then
            if RoyaltyStatement."Earned Amount (LCY)" <= Unrecouped then
                RoyaltyStatement."Recouped Amount (LCY)" := RoyaltyStatement."Earned Amount (LCY)"
            else
                RoyaltyStatement."Recouped Amount (LCY)" := Unrecouped;
        RoyaltyStatement."Payable Amount (LCY)" := RoyaltyStatement."Earned Amount (LCY)" - RoyaltyStatement."Recouped Amount (LCY)";
        RoyaltyStatement.Modify(true);
    end;

    procedure Review(var RoyaltyStatement: Record "RYL Royalty Statement")
    begin
        RoyaltyStatement.TestField(Status, RoyaltyStatement.Status::Draft);
        RoyaltyStatement.CalcFields("No. of Entries");
        RoyaltyStatement.TestField("No. of Entries");
        Recalculate(RoyaltyStatement);
        RoyaltyStatement."Reviewed By" := CopyStr(UserId(), 1, MaxStrLen(RoyaltyStatement."Reviewed By"));
        SetStatus(RoyaltyStatement, RoyaltyStatement.Status::Reviewed);
    end;

    procedure Reopen(var RoyaltyStatement: Record "RYL Royalty Statement")
    begin
        RoyaltyStatement.TestField(Status, RoyaltyStatement.Status::Reviewed);
        RoyaltyStatement."Reviewed By" := '';
        SetStatus(RoyaltyStatement, RoyaltyStatement.Status::Draft);
    end;

    procedure Approve(var RoyaltyStatement: Record "RYL Royalty Statement")
    var
        UserSetup: Record "User Setup";
    begin
        RoyaltyStatement.TestField(Status, RoyaltyStatement.Status::Reviewed);
        if not UserSetup.Get(UserId()) then
            Error(NotApproverErr, UserId());
        if not UserSetup."RYL Royalty Approver" then
            Error(NotApproverErr, UserId());
        RoyaltyStatement."Approved By" := CopyStr(UserId(), 1, MaxStrLen(RoyaltyStatement."Approved By"));
        RoyaltyStatement."Approved At" := CurrentDateTime();
        SetStatus(RoyaltyStatement, RoyaltyStatement.Status::Approved);
    end;

    local procedure SetStatus(var RoyaltyStatement: Record "RYL Royalty Statement"; NewStatus: Enum "RYL Statement Status")
    var
        StatementAuditEntry: Record "RYL Statement Audit Entry";
    begin
        StatementAuditEntry.Init();
        StatementAuditEntry."Entry No." := 0;
        StatementAuditEntry."Statement No." := RoyaltyStatement."No.";
        StatementAuditEntry."Old Status" := RoyaltyStatement.Status;
        StatementAuditEntry."New Status" := NewStatus;
        StatementAuditEntry."User ID" := CopyStr(UserId(), 1, MaxStrLen(StatementAuditEntry."User ID"));
        StatementAuditEntry."Changed At" := CurrentDateTime();
        StatementAuditEntry.Insert(true);

        RoyaltyStatement.Status := NewStatus;
        RoyaltyStatement.Modify(true);
    end;

    var
        PeriodErr: Label 'must not be before Period Start';
        NotApproverErr: Label 'User %1 is not a Royalty Approver. Set the flag in User Setup.', Comment = '%1 = user id';
}
