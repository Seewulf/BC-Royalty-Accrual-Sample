namespace PrabinBhusal.RoyaltySample.Test;

using Microsoft.Inventory.Item;
using PrabinBhusal.RoyaltySample;
using System.TestLibraries.Utilities;

codeunit 50153 "RYL Statement Approval Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "RYL Test Library";
        StatementManagement: Codeunit "RYL Statement Management";

    [Test]
    procedure NonApproverCannotApprove()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        // [SCENARIO] Approval is refused unless User Setup flags the user as Royalty Approver.
        PrepareReviewedStatement(RoyaltyStatement);
        TestLibrary.SetCurrentUserAsApprover(false);

        asserterror StatementManagement.Approve(RoyaltyStatement);
        Assert.ExpectedError('is not a Royalty Approver');
    end;

    [Test]
    procedure ApproverCanApprove()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        // [SCENARIO] A flagged approver moves the statement to Approved and is recorded on it.
        PrepareReviewedStatement(RoyaltyStatement);
        TestLibrary.SetCurrentUserAsApprover(true);

        StatementManagement.Approve(RoyaltyStatement);

        Assert.AreEqual(RoyaltyStatement.Status::Approved, RoyaltyStatement.Status, 'status');
        Assert.AreEqual(UpperCase(UserId()), UpperCase(RoyaltyStatement."Approved By"), 'approved by');
        Assert.AreNotEqual(0DT, RoyaltyStatement."Approved At", 'approved at');
    end;

    [Test]
    procedure ApprovedStatementCannotBeDeleted()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        PrepareApprovedStatement(RoyaltyStatement);

        asserterror RoyaltyStatement.Delete(true);
        Assert.ExpectedError('Status must be equal to');
    end;

    [Test]
    procedure ApprovedStatementCannotBeModified()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        PrepareApprovedStatement(RoyaltyStatement);

        RoyaltyStatement."Earned Amount (LCY)" += 1;
        asserterror RoyaltyStatement.Modify(true);
        Assert.ExpectedError('is approved and cannot be changed');
    end;

    [Test]
    procedure FrozenEntryCannotBeModified()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
    begin
        PrepareApprovedStatement(RoyaltyStatement);
        RoyaltyLedgerEntry.SetRange("Statement No.", RoyaltyStatement."No.");
        RoyaltyLedgerEntry.FindFirst();

        RoyaltyLedgerEntry."Royalty Amount (LCY)" += 1;
        asserterror RoyaltyLedgerEntry.Modify(true);
        Assert.ExpectedError('belongs to approved statement');
    end;

    [Test]
    procedure FrozenEntryCannotBeDeleted()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
    begin
        PrepareApprovedStatement(RoyaltyStatement);
        RoyaltyLedgerEntry.SetRange("Statement No.", RoyaltyStatement."No.");
        RoyaltyLedgerEntry.FindFirst();

        asserterror RoyaltyLedgerEntry.Delete(true);
        Assert.ExpectedError('belongs to approved statement');
    end;

    [Test]
    procedure EveryStatusChangeIsAudited()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
        StatementAuditEntry: Record "RYL Statement Audit Entry";
    begin
        // [SCENARIO] Draft > Reviewed > Draft > Reviewed > Approved leaves four audit entries in order.
        PrepareReviewedStatement(RoyaltyStatement);
        StatementManagement.Reopen(RoyaltyStatement);
        StatementManagement.Review(RoyaltyStatement);
        TestLibrary.SetCurrentUserAsApprover(true);
        StatementManagement.Approve(RoyaltyStatement);

        StatementAuditEntry.SetRange("Statement No.", RoyaltyStatement."No.");
        Assert.RecordCount(StatementAuditEntry, 4);
        StatementAuditEntry.FindLast();
        Assert.AreEqual(StatementAuditEntry."Old Status"::Reviewed, StatementAuditEntry."Old Status", 'last old status');
        Assert.AreEqual(StatementAuditEntry."New Status"::Approved, StatementAuditEntry."New Status", 'last new status');
        Assert.AreEqual(UpperCase(UserId()), UpperCase(StatementAuditEntry."User ID"), 'user');
    end;

    [Test]
    procedure DeletingDraftReleasesEntries()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
        StatementNo: Code[20];
    begin
        // [SCENARIO] Deleting a draft statement returns its entries to the pool so a new statement can collect them.
        PrepareReviewedStatement(RoyaltyStatement);
        StatementManagement.Reopen(RoyaltyStatement);
        StatementNo := RoyaltyStatement."No.";

        RoyaltyStatement.Delete(true);

        RoyaltyLedgerEntry.SetRange("Statement No.", StatementNo);
        Assert.RecordIsEmpty(RoyaltyLedgerEntry);
    end;

    local procedure PrepareReviewedStatement(var RoyaltyStatement: Record "RYL Royalty Statement")
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
    begin
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 8, 0);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        TestLibrary.PostSale(Item."No.", 10, 100, WorkDate());
        TestLibrary.RunCalculation();
        TestLibrary.CreateStatement(RoyaltyStatement, RoyaltyContract."No.", WorkDate(), WorkDate());
        StatementManagement.Review(RoyaltyStatement);
    end;

    local procedure PrepareApprovedStatement(var RoyaltyStatement: Record "RYL Royalty Statement")
    begin
        PrepareReviewedStatement(RoyaltyStatement);
        TestLibrary.SetCurrentUserAsApprover(true);
        StatementManagement.Approve(RoyaltyStatement);
    end;
}
