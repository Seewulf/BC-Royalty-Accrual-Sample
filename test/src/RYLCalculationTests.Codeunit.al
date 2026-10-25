namespace PrabinBhusal.RoyaltySample.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using PrabinBhusal.RoyaltySample;
using System.TestLibraries.Utilities;
using System.Threading;

codeunit 50151 "RYL Calculation Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "RYL Test Library";

    [Test]
    procedure InvoiceCreatesOneEntryAndRerunIsNoOp()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
        InvoiceNo: Code[20];
    begin
        // [SCENARIO] A posted invoice produces exactly one royalty entry; running the calculation again adds nothing.
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 8, 0);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");

        // [GIVEN] 500 units invoiced at 4.00
        InvoiceNo := TestLibrary.PostSale(Item."No.", 500, 4, WorkDate());

        // [WHEN] The calculation runs twice
        Assert.AreEqual(1, TestLibrary.RunCalculation(), 'first run should create one entry');
        Assert.AreEqual(0, TestLibrary.RunCalculation(), 'second run must not create entries');

        // [THEN] One entry with 8% of 2,000
        RoyaltyLedgerEntry.SetRange("Contract No.", RoyaltyContract."No.");
        Assert.RecordCount(RoyaltyLedgerEntry, 1);
        RoyaltyLedgerEntry.FindFirst();
        Assert.AreEqual(InvoiceNo, RoyaltyLedgerEntry."Document No.", 'document no.');
        Assert.AreEqual(RoyaltyLedgerEntry."Document Type"::"Sales Invoice", RoyaltyLedgerEntry."Document Type", 'document type');
        Assert.AreEqual(500, RoyaltyLedgerEntry.Quantity, 'quantity');
        Assert.AreEqual(2000, RoyaltyLedgerEntry."Sales Amount (LCY)", 'sales amount');
        Assert.AreEqual(160, RoyaltyLedgerEntry."Royalty Amount (LCY)", 'royalty amount');
    end;

    [Test]
    procedure CreditMemoCreatesNegativeEntry()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
        CreditMemoNo: Code[20];
    begin
        // [SCENARIO] A posted credit memo reduces the royalty with a negative entry carrying the credit memo no.
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 8, 0);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        TestLibrary.PostSale(Item."No.", 500, 4, WorkDate());

        // [GIVEN] 50 units returned at 4.00
        CreditMemoNo := TestLibrary.PostCredit(Item."No.", 50, 4, WorkDate());

        // [WHEN] The calculation runs
        Assert.AreEqual(2, TestLibrary.RunCalculation(), 'invoice and credit memo');

        // [THEN] The credit entry is -16.00 and the contract total is 144.00
        RoyaltyLedgerEntry.SetRange("Contract No.", RoyaltyContract."No.");
        RoyaltyLedgerEntry.SetRange("Document Type", RoyaltyLedgerEntry."Document Type"::"Sales Credit Memo");
        RoyaltyLedgerEntry.FindFirst();
        Assert.AreEqual(CreditMemoNo, RoyaltyLedgerEntry."Document No.", 'credit memo no.');
        Assert.AreEqual(-50, RoyaltyLedgerEntry.Quantity, 'credit quantity');
        Assert.AreEqual(-16, RoyaltyLedgerEntry."Royalty Amount (LCY)", 'credit royalty');
        RoyaltyContract.CalcFields("Royalty Earned (LCY)");
        Assert.AreEqual(144, RoyaltyContract."Royalty Earned (LCY)", 'net royalty');
    end;

    [Test]
    procedure ItemWithoutContractIsSkipped()
    var
        Item: Record Item;
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
        ValueEntry: Record "Value Entry";
        RoyaltySetup: Record "RYL Royalty Setup";
    begin
        // [SCENARIO] Sales of items with no contract create no entries, but the processing pointer still moves on.
        TestLibrary.InitSetup();
        TestLibrary.CreateRoyaltyItem(Item, '');

        TestLibrary.PostSale(Item."No.", 10, 4, WorkDate());
        Assert.AreEqual(0, TestLibrary.RunCalculation(), 'no entry expected');

        RoyaltyLedgerEntry.SetRange("Item No.", Item."No.");
        Assert.RecordIsEmpty(RoyaltyLedgerEntry);
        ValueEntry.SetRange("Item No.", Item."No.");
        ValueEntry.FindLast();
        RoyaltySetup.Get();
        Assert.AreEqual(ValueEntry."Entry No.", RoyaltySetup."Last Processed Value Entry No.", 'pointer advanced');
    end;

    [Test]
    procedure PointerSetBackCreatesNoDuplicates()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
        PointerBefore: Integer;
    begin
        // [SCENARIO] Setting the pointer back re-reads old value entries, and the unique key stops a second entry.
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 8, 0);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        PointerBefore := TestLibrary.LastValueEntryNo();
        TestLibrary.PostSale(Item."No.", 10, 100, WorkDate());
        Assert.AreEqual(1, TestLibrary.RunCalculation(), 'first run');

        // [WHEN] The pointer is set back to before the sale and the calculation runs again
        TestLibrary.SetPointerBack(PointerBefore);
        Assert.AreEqual(0, TestLibrary.RunCalculation(), 'second run after reset');

        // [THEN] Still one entry
        RoyaltyLedgerEntry.SetRange("Contract No.", RoyaltyContract."No.");
        Assert.RecordCount(RoyaltyLedgerEntry, 1);
    end;

    [Test]
    procedure ItemMappedLaterIsPickedUpAfterPointerReset()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
        PointerBefore: Integer;
    begin
        // [SCENARIO] An item linked to a contract after it was sold earns royalty once the pointer is set back.
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 10, 0);
        TestLibrary.CreateRoyaltyItem(Item, '');
        PointerBefore := TestLibrary.LastValueEntryNo();
        TestLibrary.PostSale(Item."No.", 1, 300, WorkDate());
        Assert.AreEqual(0, TestLibrary.RunCalculation(), 'not mapped yet');

        // [WHEN] The item is mapped and the pointer is set back
        Item.Get(Item."No.");
        Item."RYL Royalty Contract No." := RoyaltyContract."No.";
        Item.Modify(true);
        TestLibrary.SetPointerBack(PointerBefore);

        // [THEN] The old sale gets its royalty
        Assert.AreEqual(1, TestLibrary.RunCalculation(), 'picked up after reset');
        RoyaltyContract.CalcFields("Royalty Earned (LCY)");
        Assert.AreEqual(30, RoyaltyContract."Royalty Earned (LCY)", 'royalty');
    end;

    [Test]
    procedure BlockedContractCreatesNoEntry()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
    begin
        // [SCENARIO] Sales under a blocked contract are skipped.
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 8, 0);
        RoyaltyContract.Blocked := true;
        RoyaltyContract.Modify(true);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");

        TestLibrary.PostSale(Item."No.", 10, 100, WorkDate());

        Assert.AreEqual(0, TestLibrary.RunCalculation(), 'blocked contract');
    end;

    [Test]
    procedure SaleBeforeContractStartIsSkipped()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
    begin
        // [SCENARIO] A sale posted before the contract's starting date earns no royalty.
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 8, 0);
        RoyaltyContract.Validate("Starting Date", CalcDate('<1D>', WorkDate()));
        RoyaltyContract.Modify(true);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");

        TestLibrary.PostSale(Item."No.", 10, 100, WorkDate());

        Assert.AreEqual(0, TestLibrary.RunCalculation(), 'outside contract dates');
    end;

    [Test]
    procedure JobQueueCanRunTheCalculation()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
        TempJobQueueEntry: Record "Job Queue Entry" temporary;
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
    begin
        // [SCENARIO] The codeunit runs the way the job queue starts it, with a Job Queue Entry record.
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 8, 0);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        TestLibrary.PostSale(Item."No.", 10, 100, WorkDate());

        TempJobQueueEntry."Object Type to Run" := TempJobQueueEntry."Object Type to Run"::Codeunit;
        TempJobQueueEntry."Object ID to Run" := Codeunit::"RYL Royalty Calculation";
        Codeunit.Run(Codeunit::"RYL Royalty Calculation", TempJobQueueEntry);

        RoyaltyLedgerEntry.SetRange("Contract No.", RoyaltyContract."No.");
        Assert.RecordCount(RoyaltyLedgerEntry, 1);
    end;
}
