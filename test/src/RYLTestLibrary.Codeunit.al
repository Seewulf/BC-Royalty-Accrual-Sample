namespace PrabinBhusal.RoyaltySample.Test;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.Sales.Posting;
using PrabinBhusal.RoyaltySample;
using System.Security.User;

// Test helpers. No Tests-TestLibraries dependency so this runs on a normal online sandbox.
// Item and customer are copied from existing CRONUS records to get valid posting groups.
codeunit 50150 "RYL Test Library"
{
    procedure InitSetup()
    var
        RoyaltySetup: Record "RYL Royalty Setup";
        ValueEntry: Record "Value Entry";
    begin
        RoyaltySetup.InsertIfMissing();
        RoyaltySetup."Statement Nos." := CreateNoSeries();
        CreateJournalBatch(RoyaltySetup."Accrual Jnl. Template Name", RoyaltySetup."Accrual Jnl. Batch Name");
        RoyaltySetup."Royalty Expense Account" := CreateGLAccount();
        RoyaltySetup."Accrued Royalties Account" := CreateGLAccount();
        RoyaltySetup."Advance Paid Account" := CreateGLAccount();
        RoyaltySetup."Separate Approver Required" := false;
        // skip whatever is already there
        if ValueEntry.FindLast() then
            RoyaltySetup."Last Processed Value Entry No." := ValueEntry."Entry No.";
        RoyaltySetup.Modify();
    end;

    procedure CreateContract(var RoyaltyContract: Record "RYL Royalty Contract"; RatePct: Decimal; AdvanceAmount: Decimal)
    var
        Vendor: Record Vendor;
    begin
        Vendor.Init();
        Vendor."No." := NewCode('V');
        Vendor.Name := 'Test licensor';
        Vendor.Insert(true);

        RoyaltyContract.Init();
        RoyaltyContract."No." := NewCode('C');
        RoyaltyContract.Description := 'Test contract';
        RoyaltyContract."Licensor No." := Vendor."No.";
        RoyaltyContract."Royalty Rate %" := RatePct;
        RoyaltyContract."Advance Amount (LCY)" := AdvanceAmount;
        RoyaltyContract.Insert(true);
    end;

    procedure CreateRoyaltyItem(var Item: Record Item; ContractNo: Code[20])
    var
        SourceItem: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        SourceItem.SetRange(Type, SourceItem.Type::Inventory);
        SourceItem.SetRange(Blocked, false);
        SourceItem.SetRange("Sales Blocked", false);
        SourceItem.SetFilter("Gen. Prod. Posting Group", '<>%1', '');
        SourceItem.SetFilter("Inventory Posting Group", '<>%1', '');
        SourceItem.FindFirst();
        Item := SourceItem;
        Item."No." := NewCode('I');
        Item.Description := 'Test licensed item';
        Item."RYL Royalty Contract No." := ContractNo;
        Item."Item Tracking Code" := '';
        Item."Sales Unit of Measure" := Item."Base Unit of Measure";
        Item."Purch. Unit of Measure" := Item."Base Unit of Measure";
        Item.Insert(true);
        ItemUnitOfMeasure.Init();
        ItemUnitOfMeasure."Item No." := Item."No.";
        ItemUnitOfMeasure.Code := Item."Base Unit of Measure";
        ItemUnitOfMeasure."Qty. per Unit of Measure" := 1;
        ItemUnitOfMeasure.Insert(true);
    end;

    procedure PostSale(ItemNo: Code[20]; Quantity: Decimal; UnitPrice: Decimal; PostingDate: Date): Code[20]
    begin
        exit(PostSalesDocument(Enum::"Sales Document Type"::Invoice, ItemNo, Quantity, UnitPrice, PostingDate));
    end;

    procedure PostCredit(ItemNo: Code[20]; Quantity: Decimal; UnitPrice: Decimal; PostingDate: Date): Code[20]
    begin
        exit(PostSalesDocument(Enum::"Sales Document Type"::"Credit Memo", ItemNo, Quantity, UnitPrice, PostingDate));
    end;

    local procedure PostSalesDocument(DocumentType: Enum "Sales Document Type"; ItemNo: Code[20]; Quantity: Decimal; UnitPrice: Decimal; PostingDate: Date): Code[20]
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        SalesHeader.Init();
        SalesHeader."Document Type" := DocumentType;
        SalesHeader.Insert(true);
        SalesHeader.Validate("Sell-to Customer No.", CreateCustomer());
        SalesHeader.Validate("Posting Date", PostingDate);
        SalesHeader.Modify(true);

        SalesLine.Init();
        SalesLine."Document Type" := SalesHeader."Document Type";
        SalesLine."Document No." := SalesHeader."No.";
        SalesLine."Line No." := 10000;
        SalesLine.Validate(Type, SalesLine.Type::Item);
        SalesLine.Validate("No.", ItemNo);
        SalesLine.Validate(Quantity, Quantity);
        SalesLine.Validate("Unit Price", UnitPrice);
        SalesLine.Validate("Line Discount %", 0);
        SalesLine.Insert(true);

        SalesHeader.Ship := true;
        SalesHeader.Receive := true;
        SalesHeader.Invoice := true;
        Codeunit.Run(Codeunit::"Sales-Post", SalesHeader);

        if DocumentType = DocumentType::Invoice then begin
            SalesInvoiceHeader.SetRange("Pre-Assigned No.", SalesHeader."No.");
            SalesInvoiceHeader.FindFirst();
            exit(SalesInvoiceHeader."No.");
        end;
        SalesCrMemoHeader.SetRange("Pre-Assigned No.", SalesHeader."No.");
        SalesCrMemoHeader.FindFirst();
        exit(SalesCrMemoHeader."No.");
    end;

    procedure RunCalculation(): Integer
    var
        RoyaltyCalculation: Codeunit "RYL Royalty Calculation";
    begin
        exit(RoyaltyCalculation.ProcessNewSales());
    end;

    procedure CreateStatement(var RoyaltyStatement: Record "RYL Royalty Statement"; ContractNo: Code[20]; PeriodStart: Date; PeriodEnd: Date)
    var
        StatementManagement: Codeunit "RYL Statement Management";
    begin
        RoyaltyStatement.Init();
        RoyaltyStatement.Insert(true);
        RoyaltyStatement.Validate("Contract No.", ContractNo);
        RoyaltyStatement.Validate("Period Start", PeriodStart);
        RoyaltyStatement.Validate("Period End", PeriodEnd);
        RoyaltyStatement.Modify(true);
        StatementManagement.CollectEntries(RoyaltyStatement);
    end;

    procedure SetPointerBack(ToEntryNo: Integer)
    var
        RoyaltySetup: Record "RYL Royalty Setup";
    begin
        RoyaltySetup.Get();
        RoyaltySetup."Last Processed Value Entry No." := ToEntryNo;
        RoyaltySetup.Modify();
    end;

    procedure SetSeparateApprover(Required: Boolean)
    var
        RoyaltySetup: Record "RYL Royalty Setup";
    begin
        RoyaltySetup.Get();
        RoyaltySetup."Separate Approver Required" := Required;
        RoyaltySetup.Modify();
    end;

    procedure LastValueEntryNo(): Integer
    var
        ValueEntry: Record "Value Entry";
    begin
        if ValueEntry.FindLast() then
            exit(ValueEntry."Entry No.");
    end;

    procedure SetCurrentUserAsApprover(IsApprover: Boolean)
    var
        UserSetup: Record "User Setup";
    begin
        if not UserSetup.Get(UserId()) then begin
            UserSetup.Init();
            UserSetup."User ID" := CopyStr(UserId(), 1, MaxStrLen(UserSetup."User ID"));
            UserSetup.Insert(true);
        end;
        UserSetup."RYL Royalty Approver" := IsApprover;
        UserSetup.Modify(true);
    end;

    local procedure CreateCustomer(): Code[20]
    var
        Customer: Record Customer;
        SourceCustomer: Record Customer;
    begin
        SourceCustomer.SetRange(Blocked, SourceCustomer.Blocked::" ");
        SourceCustomer.SetFilter("Customer Posting Group", '<>%1', '');
        SourceCustomer.SetFilter("Gen. Bus. Posting Group", '<>%1', '');
        SourceCustomer.SetRange("Currency Code", '');
        SourceCustomer.FindFirst();
        Customer := SourceCustomer;
        Customer."No." := NewCode('CU');
        Customer.Name := 'Test customer';
        // plain net prices so the expected amounts are simple
        Customer."Prices Including VAT" := false;
        Customer."Customer Disc. Group" := '';
        Customer."Customer Price Group" := '';
        Customer."Invoice Disc. Code" := '';
        Customer."Location Code" := '';
        Customer.Insert(true);
        exit(Customer."No.");
    end;

    local procedure CreateGLAccount(): Code[20]
    var
        GLAccount: Record "G/L Account";
    begin
        GLAccount.Init();
        GLAccount."No." := NewCode('G');
        GLAccount.Name := 'Royalty test account';
        GLAccount."Account Type" := GLAccount."Account Type"::Posting;
        GLAccount."Direct Posting" := true;
        GLAccount.Insert(true);
        exit(GLAccount."No.");
    end;

    local procedure CreateNoSeries(): Code[20]
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        NoSeries.Init();
        NoSeries.Code := NewCode('NS');
        NoSeries."Default Nos." := true;
        NoSeries.Insert(true);
        NoSeriesLine.Init();
        NoSeriesLine."Series Code" := NoSeries.Code;
        NoSeriesLine."Line No." := 10000;
        // unique per test, the runner does not roll back between methods
        NoSeriesLine."Starting No." := CopyStr(NoSeries.Code, 1, 8) + '-0001';
        NoSeriesLine."Ending No." := CopyStr(NoSeries.Code, 1, 8) + '-9999';
        NoSeriesLine.Insert(true);
        exit(NoSeries.Code);
    end;

    local procedure CreateJournalBatch(var TemplateName: Code[10]; var BatchName: Code[10])
    var
        GenJournalTemplate: Record "Gen. Journal Template";
        GenJournalBatch: Record "Gen. Journal Batch";
    begin
        GenJournalTemplate.Init();
        GenJournalTemplate.Name := CopyStr(NewCode('T'), 1, MaxStrLen(GenJournalTemplate.Name));
        GenJournalTemplate.Type := GenJournalTemplate.Type::General;
        GenJournalTemplate.Insert(true);
        GenJournalBatch.Init();
        GenJournalBatch."Journal Template Name" := GenJournalTemplate.Name;
        GenJournalBatch.Name := 'ROYALTY';
        GenJournalBatch."Copy VAT Setup to Jnl. Lines" := false;
        GenJournalBatch.Insert(true);
        TemplateName := GenJournalTemplate.Name;
        BatchName := GenJournalBatch.Name;
    end;

    local procedure NewCode(Prefix: Code[2]): Code[20]
    begin
        exit(CopyStr(Prefix + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 10));
    end;
}
