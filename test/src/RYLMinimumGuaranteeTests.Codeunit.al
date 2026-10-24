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
}
