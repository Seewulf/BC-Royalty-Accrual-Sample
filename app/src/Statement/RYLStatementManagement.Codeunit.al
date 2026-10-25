namespace PrabinBhusal.RoyaltySample;

using System.Security.User;

// Statement handling: collect entries, MG recoupment, draft -> reviewed -> approved.
codeunit 50101 "RYL Statement Management"
{
    Permissions = tabledata "RYL Royalty Ledger Entry" = rm,
                  tabledata "RYL Statement Audit Entry" = ri;

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

        // no lower date limit, so late postings into a closed period land on the next statement
        RoyaltyLedgerEntry.SetCurrentKey("Contract No.", "Posting Date", "Statement No.");
        RoyaltyLedgerEntry.SetRange("Contract No.", RoyaltyStatement."Contract No.");
        RoyaltyLedgerEntry.SetFilter("Posting Date", '..%1', RoyaltyStatement."Period End");
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
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
    begin
        RoyaltyStatement.TestField(Status, RoyaltyStatement.Status::Draft);

        RoyaltyLedgerEntry.SetCurrentKey("Statement No.");
        RoyaltyLedgerEntry.SetRange("Statement No.", RoyaltyStatement."No.");
        RoyaltyLedgerEntry.CalcSums("Royalty Amount (LCY)");
        RoyaltyStatement."Earned Amount (LCY)" := RoyaltyLedgerEntry."Royalty Amount (LCY)";
        CalcRecoupment(RoyaltyStatement);
        RoyaltyStatement.Modify(true);
    end;

    procedure Review(var RoyaltyStatement: Record "RYL Royalty Statement")
    begin
        RoyaltyStatement.TestField(Status, RoyaltyStatement.Status::Draft);
        RoyaltyStatement.TestField("Contract No.");
        RoyaltyStatement.TestField("Period End");
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
        RoyaltySetup: Record "RYL Royalty Setup";
        CheckStatement: Record "RYL Royalty Statement";
    begin
        RoyaltyStatement.TestField(Status, RoyaltyStatement.Status::Reviewed);
        if not UserSetup.Get(UserId()) then
            Error(NotApproverErr, UserId());
        if not UserSetup."RYL Royalty Approver" then
            Error(NotApproverErr, UserId());
        if RoyaltySetup.Get() then
            if RoyaltySetup."Separate Approver Required" and (UpperCase(RoyaltyStatement."Reviewed By") = UpperCase(UserId())) then
                Error(SameUserErr, RoyaltyStatement."No.");

        // another statement of the same contract may have been approved since this one was reviewed
        RoyaltyStatement.LockTable();
        CheckStatement := RoyaltyStatement;
        CalcRecoupment(CheckStatement);
        if CheckStatement."Recouped Amount (LCY)" <> RoyaltyStatement."Recouped Amount (LCY)" then
            Error(RecoupmentChangedErr, RoyaltyStatement."No.");

        RoyaltyStatement."Approved By" := CopyStr(UserId(), 1, MaxStrLen(RoyaltyStatement."Approved By"));
        RoyaltyStatement."Approved At" := CurrentDateTime();
        SetStatus(RoyaltyStatement, RoyaltyStatement.Status::Approved);
    end;

    local procedure CalcRecoupment(var RoyaltyStatement: Record "RYL Royalty Statement")
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        ApprovedStatement: Record "RYL Royalty Statement";
        TotalRecouped: Decimal;
    begin
        RoyaltyContract.Get(RoyaltyStatement."Contract No.");
        ApprovedStatement.SetCurrentKey("Contract No.", Status);
        ApprovedStatement.SetRange("Contract No.", RoyaltyStatement."Contract No.");
        ApprovedStatement.SetRange(Status, ApprovedStatement.Status::Approved);
        ApprovedStatement.CalcSums("Earned Amount (LCY)", "Recouped Amount (LCY)");

        // total recouped = everything earned so far, but never more than the advance and never below zero.
        // this statement takes the difference, so a credit period gives part of the advance back.
        TotalRecouped := ApprovedStatement."Earned Amount (LCY)" + RoyaltyStatement."Earned Amount (LCY)";
        if TotalRecouped > RoyaltyContract."Advance Amount (LCY)" then
            TotalRecouped := RoyaltyContract."Advance Amount (LCY)";
        if TotalRecouped < 0 then
            TotalRecouped := 0;

        RoyaltyStatement."Recouped Amount (LCY)" := TotalRecouped - ApprovedStatement."Recouped Amount (LCY)";
        RoyaltyStatement."Payable Amount (LCY)" := RoyaltyStatement."Earned Amount (LCY)" - RoyaltyStatement."Recouped Amount (LCY)";
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
        SameUserErr: Label 'Statement %1 was reviewed by you. Another user has to approve it.', Comment = '%1 = statement no.';
        RecoupmentChangedErr: Label 'The advance recouped on statement %1 has changed since it was reviewed, because another statement of the contract was approved. Reopen the statement and review it again.', Comment = '%1 = statement no.';
}
