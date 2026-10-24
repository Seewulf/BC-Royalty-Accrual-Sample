namespace PrabinBhusal.RoyaltySample.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using PrabinBhusal.RoyaltySample;
using System.TestLibraries.Utilities;

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
    begin
        // [SCENARIO] A posted credit memo reduces the royalty with a negative entry that keeps its own document reference.
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 8, 0);
        TestLibrary.CreateRoyaltyItem(Item, RoyaltyContract."No.");
        TestLibrary.PostSale(Item."No.", 500, 4, WorkDate());

        // [GIVEN] 50 units returned at 4.00
        TestLibrary.PostCredit(Item."No.", 50, 4, WorkDate());

        // [WHEN] The calculation runs
        Assert.AreEqual(2, TestLibrary.RunCalculation(), 'invoice and credit memo');

        // [THEN] The credit entry is -16.00 and the contract total is 144.00
        RoyaltyLedgerEntry.SetRange("Contract No.", RoyaltyContract."No.");
        RoyaltyLedgerEntry.SetRange("Document Type", RoyaltyLedgerEntry."Document Type"::"Sales Credit Memo");
        RoyaltyLedgerEntry.FindFirst();
        Assert.AreEqual(-50, RoyaltyLedgerEntry.Quantity, 'credit quantity');
        Assert.AreEqual(-16, RoyaltyLedgerEntry."Royalty Amount (LCY)", 'credit royalty');
        RoyaltyContract.CalcFields("Royalty Earned (LCY)");
        Assert.AreEqual(144, RoyaltyContract."Royalty Earned (LCY)", 'net royalty');
    end;

    [Test]
    procedure ItemWithoutContractIsSkipped()
    var
        RoyaltyContract: Record "RYL Royalty Contract";
        Item: Record Item;
        RoyaltyLedgerEntry: Record "RYL Royalty Ledger Entry";
        ValueEntry: Record "Value Entry";
        RoyaltySetup: Record "RYL Royalty Setup";
    begin
        // [SCENARIO] Sales of items with no contract create no entries, but the processing pointer still moves on.
        TestLibrary.InitSetup();
        TestLibrary.CreateContract(RoyaltyContract, 8, 0);
        TestLibrary.CreateRoyaltyItem(Item, '');

        TestLibrary.PostSale(Item."No.", 10, 4, WorkDate());
        Assert.AreEqual(0, TestLibrary.RunCalculation(), 'no entry expected');

        RoyaltyLedgerEntry.SetRange("Item No.", Item."No.");
        Assert.RecordIsEmpty(RoyaltyLedgerEntry);
        ValueEntry.FindLast();
        RoyaltySetup.Get();
        Assert.AreEqual(ValueEntry."Entry No.", RoyaltySetup."Last Processed Value Entry No.", 'pointer advanced');
    end;
}
