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

        RoyaltyStatement.Get(RoyaltyStatement."No.");
        Assert.AreEqual(RoyaltyStatement.Status::Approved, RoyaltyStatement.Status, 'status');
        Assert.AreEqual(UpperCase(UserId()), UpperCase(RoyaltyStatement."Approved By"), 'approved by');
        Assert.AreNotEqual(0DT, RoyaltyStatement."Approved At", 'approved at');
    end;

    [Test]
    procedure ReviewerCannotApproveWhenSeparateApproverRequired()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        // [SCENARIO] With "Separate Approver Required" on, the user who reviewed cannot also approve.
        PrepareReviewedStatement(RoyaltyStatement);
        TestLibrary.SetCurrentUserAsApprover(true);
        TestLibrary.SetSeparateApprover(true);

        asserterror StatementManagement.Approve(RoyaltyStatement);
        Assert.ExpectedError('Another user has to approve it');
    end;

    [Test]
    procedure ApprovedStatementCannotBeDeleted()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        // [SCENARIO] An approved statement cannot be deleted.
        PrepareApprovedStatement(RoyaltyStatement);

        asserterror RoyaltyStatement.Delete(true);
        Assert.ExpectedError('Status must be equal to');
    end;

    [Test]
    procedure ApprovedStatementCannotBeModified()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        // [SCENARIO] An approved statement cannot be changed.
        PrepareApprovedStatement(RoyaltyStatement);

        RoyaltyStatement."Earned Amount (LCY)" += 1;
        asserterror RoyaltyStatement.Modify(true);
        Assert.ExpectedError('is approved and cannot be changed');
    end;

    [Test]
    procedure ApprovedStatementCannotBeSetBackToDraft()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        // [SCENARIO] Changing the status in memory and saving is caught, because the trigger reads the stored record.
        PrepareApprovedStatement(RoyaltyStatement);

        RoyaltyStatement.Status := RoyaltyStatement.Status::Draft;
        asserterror RoyaltyStatement.Modify(true);
        Assert.ExpectedError('is approved and cannot be changed');
    end;

    [Test]
    procedure ApprovedStatementCannotBeReopened()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        // [SCENARIO] Reopen only works on Reviewed statements, so an approved one stays frozen.
        PrepareApprovedStatement(RoyaltyStatement);

        asserterror StatementManagement.Reopen(RoyaltyStatement);
        Assert.ExpectedError('Status must be equal to');
    end;

    [Test]
    procedure ApprovedStatementCannotBeRenamed()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        // [SCENARIO] The statement no. is the document no. in the G/L, so it cannot be renamed.
        PrepareApprovedStatement(RoyaltyStatement);

        asserterror RoyaltyStatement.Rename('RENAMED-1');
        Assert.ExpectedError('cannot be renamed');
    end;

    [Test]
    procedure FrozenEntryCannotBeModified()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
    begin
        // [SCENARIO] Entries on an approved statement cannot be changed.
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
        // [SCENARIO] Entries on an approved statement cannot be deleted, even if the statement no. is cleared in memory first.
        PrepareApprovedStatement(RoyaltyStatement);
        RoyaltyLedgerEntry.SetRange("Statement No.", RoyaltyStatement."No.");
        RoyaltyLedgerEntry.FindFirst();

        RoyaltyLedgerEntry."Statement No." := '';
        asserterror RoyaltyLedgerEntry.Delete(true);
        Assert.ExpectedError('belongs to approved statement');
    end;

    [Test]
    procedure EveryStatusChangeIsAudited()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
        StatementAuditEntry: Record "RYL Statement Audit Entry";
    begin
        // [SCENARIO] Draft > Reviewed > Draft > Reviewed > Approved leaves four audit entries in that order.
        PrepareReviewedStatement(RoyaltyStatement);
        StatementManagement.Reopen(RoyaltyStatement);
        StatementManagement.Review(RoyaltyStatement);
        TestLibrary.SetCurrentUserAsApprover(true);
        StatementManagement.Approve(RoyaltyStatement);

        StatementAuditEntry.SetRange("Statement No.", RoyaltyStatement."No.");
        Assert.RecordCount(StatementAuditEntry, 4);
        StatementAuditEntry.FindSet();
        CheckAuditEntry(StatementAuditEntry, StatementAuditEntry."Old Status"::Draft, StatementAuditEntry."New Status"::Reviewed);
        StatementAuditEntry.Next();
        CheckAuditEntry(StatementAuditEntry, StatementAuditEntry."Old Status"::Reviewed, StatementAuditEntry."New Status"::Draft);
        StatementAuditEntry.Next();
        CheckAuditEntry(StatementAuditEntry, StatementAuditEntry."Old Status"::Draft, StatementAuditEntry."New Status"::Reviewed);
        StatementAuditEntry.Next();
        CheckAuditEntry(StatementAuditEntry, StatementAuditEntry."Old Status"::Reviewed, StatementAuditEntry."New Status"::Approved);
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

    [Test]
    procedure ChangingThePeriodReleasesEntries()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
    begin
        // [SCENARIO] Changing the period of a draft after collecting lets go of the entries and clears the amounts.
        PrepareReviewedStatement(RoyaltyStatement);
        StatementManagement.Reopen(RoyaltyStatement);

        RoyaltyStatement.Validate("Period End", CalcDate('<1D>', RoyaltyStatement."Period End"));
        RoyaltyStatement.Modify(true);

        RoyaltyLedgerEntry.SetRange("Statement No.", RoyaltyStatement."No.");
        Assert.RecordIsEmpty(RoyaltyLedgerEntry);
        Assert.AreEqual(0, RoyaltyStatement."Earned Amount (LCY)", 'earned cleared');
    end;

    [Test]
    procedure LatePostingGoesOnTheNextStatement()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
        Statement1: Record "RYL Royalty Statement";
        Statement2: Record "RYL Royalty Statement";
        NextMonth: Date;
    begin
        // [SCENARIO] A sale back-dated into a period that is already approved is picked up by the next statement.
        TestLibrary.InitSetup();
        TestLibrary.SetCurrentUserAsApprover(true);
        TestLibrary.CreateContract(RoyaltyContract, 10, 0);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        NextMonth := CalcDate('<CM+1D>', WorkDate());
        TestLibrary.PostSale(Item."No.", 1, 1000, WorkDate());
        TestLibrary.RunCalculation();
        TestLibrary.CreateStatement(Statement1, RoyaltyContract."No.", CalcDate('<-CM>', WorkDate()), CalcDate('<CM>', WorkDate()));
        StatementManagement.Review(Statement1);
        StatementManagement.Approve(Statement1);

        // [GIVEN] Another sale dated in the approved month
        TestLibrary.PostSale(Item."No.", 1, 500, WorkDate());
        TestLibrary.RunCalculation();

        // [WHEN] The next month's statement collects entries
        TestLibrary.CreateStatement(Statement2, RoyaltyContract."No.", NextMonth, CalcDate('<CM>', NextMonth));

        // [THEN] The late sale is on it
        Statement2.CalcFields("No. of Entries");
        Assert.AreEqual(1, Statement2."No. of Entries", 'late entry collected');
        Assert.AreEqual(50, Statement2."Earned Amount (LCY)", 'late royalty');
    end;

    [Test]
    procedure NewStatementShowsNoEntriesBeforeItHasANumber()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
        RoyaltyStatement: TestPage "RYL Royalty Statement";
    begin
        // [SCENARIO] A new statement has no No. yet. Its Entries part must stay empty even when unassigned entries exist.
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 8, 0);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        TestLibrary.PostSale(Item."No.", 1, 100, WorkDate());
        TestLibrary.RunCalculation();

        // [WHEN] A new statement card is opened
        RoyaltyStatement.OpenNew();

        // [THEN] The Entries part shows nothing
        Assert.IsFalse(RoyaltyStatement.Lines.First(), 'entries shown on a statement without a No.');
        RoyaltyStatement.Close();
    end;

    local procedure CheckAuditEntry(StatementAuditEntry: Record "RYL Statement Audit Entry"; OldStatus: Enum "RYL Statement Status"; NewStatus: Enum "RYL Statement Status")
    begin
        Assert.AreEqual(OldStatus, StatementAuditEntry."Old Status", 'old status');
        Assert.AreEqual(NewStatus, StatementAuditEntry."New Status", 'new status');
        Assert.AreEqual(UpperCase(UserId()), UpperCase(StatementAuditEntry."User ID"), 'user');
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
