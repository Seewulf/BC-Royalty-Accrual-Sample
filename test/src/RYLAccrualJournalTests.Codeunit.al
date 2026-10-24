namespace PrabinBhusal.RoyaltySample.Test;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Inventory.Item;
using PrabinBhusal.RoyaltySample;
using System.TestLibraries.Utilities;

codeunit 50154 "RYL Accrual Journal Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "RYL Test Library";
        StatementManagement: Codeunit "RYL Statement Management";
        AccrualJournal: Codeunit "RYL Accrual Journal";

    [Test]
    procedure ApprovedStatementCreatesBalancedJournalLines()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
        RoyaltySetup: Record "RYL Royalty Setup";
        GenJournalLine: Record "Gen. Journal Line";
    begin
        // [SCENARIO] Earned 500 with 200 recouped gives three balanced lines: expense 500, advance -200, payable -300. Nothing is posted.
        PrepareApprovedStatement(RoyaltyStatement, 10, 200, 5000);

        Assert.AreEqual(3, AccrualJournal.CreateLines(RoyaltyStatement), 'line count');

        RoyaltySetup.Get();
        GenJournalLine.SetRange("Journal Template Name", RoyaltySetup."Accrual Jnl. Template Name");
        GenJournalLine.SetRange("Journal Batch Name", RoyaltySetup."Accrual Jnl. Batch Name");
        GenJournalLine.SetRange("Document No.", RoyaltyStatement."No.");
        GenJournalLine.CalcSums(Amount);
        Assert.AreEqual(0, GenJournalLine.Amount, 'journal must balance');
        GenJournalLine.SetRange("Account No.", RoyaltySetup."Royalty Expense Account");
        GenJournalLine.FindFirst();
        Assert.AreEqual(500, GenJournalLine.Amount, 'expense');
        Assert.AreEqual(RoyaltyStatement."Period End", GenJournalLine."Posting Date", 'posting date');
        GenJournalLine.SetRange("Account No.", RoyaltySetup."Advance Paid Account");
        GenJournalLine.FindFirst();
        Assert.AreEqual(-200, GenJournalLine.Amount, 'recoupment');
        GenJournalLine.SetRange("Account No.", RoyaltySetup."Accrued Royalties Account");
        GenJournalLine.FindFirst();
        Assert.AreEqual(-300, GenJournalLine.Amount, 'payable');
    end;

    [Test]
    procedure LinesCannotBeCreatedTwice()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        // [SCENARIO] A second request while the lines are still in the journal is refused.
        PrepareApprovedStatement(RoyaltyStatement, 10, 0, 1000);
        AccrualJournal.CreateLines(RoyaltyStatement);

        asserterror AccrualJournal.CreateLines(RoyaltyStatement);
        Assert.ExpectedError('already exist in batch');
    end;

    [Test]
    procedure DraftStatementCannotBeAccrued()
    var
        RoyaltyStatement: Record "RYL Royalty Statement";
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
    begin
        // [SCENARIO] Accrual lines require an approved statement.
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 10, 0);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        TestLibrary.PostSale(Item."No.", 1, 1000, WorkDate());
        TestLibrary.RunCalculation();
        TestLibrary.CreateStatement(RoyaltyStatement, RoyaltyContract."No.", WorkDate(), WorkDate());

        asserterror AccrualJournal.CreateLines(RoyaltyStatement);
        Assert.ExpectedError('Status must be equal to');
    end;

    local procedure PrepareApprovedStatement(var RoyaltyStatement: Record "RYL Royalty Statement"; RatePct: Decimal; AdvanceAmount: Decimal; SalesAmount: Decimal)
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
    begin
        TestLibrary.InitSetup();
        TestLibrary.SetCurrentUserAsApprover(true);
        TestLibrary.CreateContract(RoyaltyContract, RatePct, AdvanceAmount);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        TestLibrary.PostSale(Item."No.", 1, SalesAmount, WorkDate());
        TestLibrary.RunCalculation();
        TestLibrary.CreateStatement(RoyaltyStatement, RoyaltyContract."No.", WorkDate(), WorkDate());
        StatementManagement.Review(RoyaltyStatement);
        StatementManagement.Approve(RoyaltyStatement);
    end;
}
