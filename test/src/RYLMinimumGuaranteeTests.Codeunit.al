namespace PrabinBhusal.RoyaltySample.Test;

using Microsoft.Inventory.Item;
using PrabinBhusal.RoyaltySample;
using System.TestLibraries.Utilities;

codeunit 50152 "RYL Minimum Guarantee Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "RYL Test Library";
        StatementManagement: Codeunit "RYL Statement Management";

    [Test]
    procedure AdvanceIsRecoupedBeforeAnythingIsPayable()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
        Statement1: Record "RYL Royalty Statement";
        Statement2: Record "RYL Royalty Statement";
        Period1Start: Date;
        Period1End: Date;
        Period2Start: Date;
        Period2End: Date;
    begin
        // [SCENARIO] Advance 20,000 fully recoupable, 8% royalty.
        // Sales of 150,000 earn 12,000: all recouped, nothing payable, 8,000 of the advance left.
        // Further sales of 150,000 earn 12,000: 8,000 recouped (advance used up), 4,000 payable.
        TestLibrary.InitSetup();
        TestLibrary.SetCurrentUserAsApprover(true);
        TestLibrary.CreateContract(RoyaltyContract, 8, 20000);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        Period1Start := CalcDate('<-CM>', WorkDate());
        Period1End := CalcDate('<CM>', WorkDate());
        Period2Start := CalcDate('<1D>', Period1End);
        Period2End := CalcDate('<CM>', Period2Start);

        // [GIVEN] Period 1 sales of 150,000, collected on an approved statement
        TestLibrary.PostSale(Item."No.", 1000, 150, WorkDate());
        TestLibrary.RunCalculation();
        TestLibrary.CreateStatement(Statement1, RoyaltyContract."No.", Period1Start, Period1End);
        Assert.AreEqual(12000, Statement1."Earned Amount (LCY)", 'period 1 earned');
        Assert.AreEqual(12000, Statement1."Recouped Amount (LCY)", 'period 1 recouped');
        Assert.AreEqual(0, Statement1."Payable Amount (LCY)", 'period 1 payable');
        StatementManagement.Review(Statement1);
        StatementManagement.Approve(Statement1);
        Assert.AreEqual(8000, RoyaltyContract.UnrecoupedAdvance(), 'advance left after period 1');

        // [WHEN] Period 2 sales of another 150,000
        TestLibrary.PostSale(Item."No.", 1000, 150, Period2Start);
        TestLibrary.RunCalculation();
        TestLibrary.CreateStatement(Statement2, RoyaltyContract."No.", Period2Start, Period2End);

        // [THEN] Only the remaining 8,000 is recouped and 4,000 becomes payable
        Assert.AreEqual(12000, Statement2."Earned Amount (LCY)", 'period 2 earned');
        Assert.AreEqual(8000, Statement2."Recouped Amount (LCY)", 'period 2 recouped');
        Assert.AreEqual(4000, Statement2."Payable Amount (LCY)", 'period 2 payable');
    end;

    [Test]
    procedure UnapprovedStatementDoesNotConsumeAdvance()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        // [SCENARIO] A draft statement shows the recoupment it would make, but the advance balance only moves on approval.
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 10, 1000);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        TestLibrary.PostSale(Item."No.", 1, 5000, WorkDate());
        TestLibrary.RunCalculation();

        TestLibrary.CreateStatement(RoyaltyStatement, RoyaltyContract."No.", WorkDate(), WorkDate());

        Assert.AreEqual(500, RoyaltyStatement."Recouped Amount (LCY)", 'draft recoupment');
        Assert.AreEqual(1000, RoyaltyContract.UnrecoupedAdvance(), 'advance untouched while draft');
    end;

    [Test]
    procedure SecondApprovalRefusedWhenAdvanceAlreadyUsed()
    var
        Statement1: Record "RYL Royalty Statement";
        Statement2: Record "RYL Royalty Statement";
    begin
        // [SCENARIO] Advance 1,000 at 10%. Two periods earn 600 each and are both reviewed before either is approved.
        // [GIVEN] Both reviewed, each showing 600 recouped
        PrepareTwoReviewedStatements(Statement1, Statement2);
        Assert.AreEqual(600, Statement2."Recouped Amount (LCY)", 'statement 2 before');

        // [WHEN] Statement 1 is approved
        StatementManagement.Approve(Statement1);

        // [THEN] Statement 2 cannot be approved with the old figures
        asserterror StatementManagement.Approve(Statement2);
        Assert.ExpectedError('has changed since it was reviewed');
    end;

    [Test]
    procedure ReviewAgainRecoupsOnlyWhatIsLeft()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Statement1: Record "RYL Royalty Statement";
        Statement2: Record "RYL Royalty Statement";
    begin
        // [SCENARIO] After statement 1 is approved, statement 2 is reopened and reviewed again and recoups only the 400 left.
        PrepareTwoReviewedStatements(Statement1, Statement2);
        StatementManagement.Approve(Statement1);

        StatementManagement.Reopen(Statement2);
        StatementManagement.Review(Statement2);
        StatementManagement.Approve(Statement2);

        Assert.AreEqual(400, Statement2."Recouped Amount (LCY)", 'statement 2 recouped');
        Assert.AreEqual(200, Statement2."Payable Amount (LCY)", 'statement 2 payable');
        RoyaltyContract.Get(Statement2."Contract No.");
        Assert.AreEqual(0, RoyaltyContract.UnrecoupedAdvance(), 'advance fully used');
    end;

    [Test]
    procedure CreditPeriodGivesAdvanceBack()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
        Statement1: Record "RYL Royalty Statement";
        Statement2: Record "RYL Royalty Statement";
        Statement3: Record "RYL Royalty Statement";
        NextMonth: Date;
    begin
        // [SCENARIO] Advance 20,000 at 8%. Period 1 earns 12,000. Period 2 is a net credit of -2,000.
        // Period 3 earns 12,000. The credit gives 2,000 of the advance back, so period 3 recoups 10,000 and pays 2,000.
        TestLibrary.InitSetup();
        TestLibrary.SetCurrentUserAsApprover(true);
        TestLibrary.CreateContract(RoyaltyContract, 8, 20000);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        NextMonth := CalcDate('<CM+1D>', WorkDate());

        // [GIVEN] Period 1: sales of 150,000, approved
        TestLibrary.PostSale(Item."No.", 1000, 150, WorkDate());
        TestLibrary.RunCalculation();
        TestLibrary.CreateStatement(Statement1, RoyaltyContract."No.", CalcDate('<-CM>', WorkDate()), CalcDate('<CM>', WorkDate()));
        StatementManagement.Review(Statement1);
        StatementManagement.Approve(Statement1);

        // [WHEN] Period 2: a credit of 25,000 (royalty -2,000)
        TestLibrary.PostCredit(Item."No.", 1, 25000, NextMonth);
        TestLibrary.RunCalculation();
        TestLibrary.CreateStatement(Statement2, RoyaltyContract."No.", NextMonth, CalcDate('<9D>', NextMonth));

        // [THEN] Nothing payable, 2,000 of the advance comes back
        Assert.AreEqual(-2000, Statement2."Earned Amount (LCY)", 'period 2 earned');
        Assert.AreEqual(-2000, Statement2."Recouped Amount (LCY)", 'period 2 recouped');
        Assert.AreEqual(0, Statement2."Payable Amount (LCY)", 'period 2 payable');
        StatementManagement.Review(Statement2);
        StatementManagement.Approve(Statement2);
        Assert.AreEqual(10000, RoyaltyContract.UnrecoupedAdvance(), 'advance left after credit');

        // [THEN] Period 3: sales of 150,000 recoup the 10,000 left and pay 2,000
        TestLibrary.PostSale(Item."No.", 1000, 150, CalcDate('<15D>', NextMonth));
        TestLibrary.RunCalculation();
        TestLibrary.CreateStatement(Statement3, RoyaltyContract."No.", CalcDate('<10D>', NextMonth), CalcDate('<CM>', NextMonth));
        Assert.AreEqual(12000, Statement3."Earned Amount (LCY)", 'period 3 earned');
        Assert.AreEqual(10000, Statement3."Recouped Amount (LCY)", 'period 3 recouped');
        Assert.AreEqual(2000, Statement3."Payable Amount (LCY)", 'period 3 payable');
    end;

    [Test]
    procedure InvoiceAndCreditOnSameDayAreBothCollected()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
        RoyaltyStatement: Record "RYL Royalty Statement";
    begin
        // [SCENARIO] Advance 500 at 8%. Invoice 10 x 1,000 and credit 2 x 1,000 posted on the same day.
        // Both entries go on the statement: earned 640, recouped 500, payable 140.
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 8, 500);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        TestLibrary.PostSale(Item."No.", 10, 1000, WorkDate());
        TestLibrary.PostCredit(Item."No.", 2, 1000, WorkDate());
        TestLibrary.RunCalculation();

        TestLibrary.CreateStatement(RoyaltyStatement, RoyaltyContract."No.", CalcDate('<-CM>', WorkDate()), CalcDate('<CM>', WorkDate()));

        RoyaltyStatement.CalcFields("No. of Entries");
        Assert.AreEqual(2, RoyaltyStatement."No. of Entries", 'entries collected');
        Assert.AreEqual(640, RoyaltyStatement."Earned Amount (LCY)", 'earned');
        Assert.AreEqual(500, RoyaltyStatement."Recouped Amount (LCY)", 'recouped');
        Assert.AreEqual(140, RoyaltyStatement."Payable Amount (LCY)", 'payable');
    end;

    local procedure PrepareTwoReviewedStatements(var Statement1: Record "RYL Royalty Statement"; var Statement2: Record "RYL Royalty Statement")
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
        Period2Start: Date;
    begin
        TestLibrary.InitSetup();
        TestLibrary.SetCurrentUserAsApprover(true);
        TestLibrary.CreateContract(RoyaltyContract, 10, 1000);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        Period2Start := CalcDate('<CM+1D>', WorkDate());
        TestLibrary.PostSale(Item."No.", 1, 6000, WorkDate());
        TestLibrary.PostSale(Item."No.", 1, 6000, Period2Start);
        TestLibrary.RunCalculation();
        TestLibrary.CreateStatement(Statement1, RoyaltyContract."No.", CalcDate('<-CM>', WorkDate()), CalcDate('<CM>', WorkDate()));
        TestLibrary.CreateStatement(Statement2, RoyaltyContract."No.", Period2Start, CalcDate('<CM>', Period2Start));
        StatementManagement.Review(Statement1);
        StatementManagement.Review(Statement2);
    end;
}
