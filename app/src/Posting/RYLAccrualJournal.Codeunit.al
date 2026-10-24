namespace PrabinBhusal.RoyaltySample;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.GeneralLedger.Ledger;

// Journal lines for an approved statement. Only creates lines, posting is done from the journal.
codeunit 50102 "RYL Accrual Journal"
{
    procedure CreateLines(RoyaltyStatement: Record "RYL Royalty Statement") LinesCreated: Integer
    var
        RoyaltySetup: Record "RYL Royalty Setup";
        GenJournalBatch: Record "Gen. Journal Batch";
        GenJournalLine: Record "Gen. Journal Line";
        GLEntry: Record "G/L Entry";
        LineNo: Integer;
    begin
        RoyaltyStatement.TestField(Status, RoyaltyStatement.Status::Approved);
        RoyaltySetup.Get();
        RoyaltySetup.TestField("Accrual Jnl. Template Name");
        RoyaltySetup.TestField("Accrual Jnl. Batch Name");
        RoyaltySetup.TestField("Royalty Expense Account");
        RoyaltySetup.TestField("Accrued Royalties Account");
        RoyaltySetup.TestField("Advance Paid Account");
        GenJournalBatch.Get(RoyaltySetup."Accrual Jnl. Template Name", RoyaltySetup."Accrual Jnl. Batch Name");

        GLEntry.SetRange("Document No.", RoyaltyStatement."No.");
        if not GLEntry.IsEmpty() then
            Error(AlreadyPostedErr, RoyaltyStatement."No.");

        GenJournalLine.SetRange("Journal Template Name", GenJournalBatch."Journal Template Name");
        GenJournalLine.SetRange("Journal Batch Name", GenJournalBatch.Name);
        GenJournalLine.SetRange("Document No.", RoyaltyStatement."No.");
        if not GenJournalLine.IsEmpty() then
            Error(AlreadyInJournalErr, RoyaltyStatement."No.", GenJournalBatch.Name);

        GenJournalLine.SetRange("Document No.");
        if GenJournalLine.FindLast() then;
        LineNo := GenJournalLine."Line No.";

        if RoyaltyStatement."Earned Amount (LCY)" <> 0 then
            LinesCreated += InsertLine(GenJournalLine, GenJournalBatch, RoyaltyStatement, LineNo, RoyaltySetup."Royalty Expense Account", RoyaltyStatement."Earned Amount (LCY)", EarnedLbl);
        if RoyaltyStatement."Recouped Amount (LCY)" <> 0 then
            LinesCreated += InsertLine(GenJournalLine, GenJournalBatch, RoyaltyStatement, LineNo, RoyaltySetup."Advance Paid Account", -RoyaltyStatement."Recouped Amount (LCY)", RecoupedLbl);
        if RoyaltyStatement."Payable Amount (LCY)" <> 0 then
            LinesCreated += InsertLine(GenJournalLine, GenJournalBatch, RoyaltyStatement, LineNo, RoyaltySetup."Accrued Royalties Account", -RoyaltyStatement."Payable Amount (LCY)", PayableLbl);
    end;

    local procedure InsertLine(var GenJournalLine: Record "Gen. Journal Line"; GenJournalBatch: Record "Gen. Journal Batch"; RoyaltyStatement: Record "RYL Royalty Statement"; var LineNo: Integer; AccountNo: Code[20]; Amount: Decimal; DescriptionLbl: Text): Integer
    begin
        LineNo += 10000;
        GenJournalLine.Init();
        GenJournalLine."Journal Template Name" := GenJournalBatch."Journal Template Name";
        GenJournalLine."Journal Batch Name" := GenJournalBatch.Name;
        GenJournalLine."Line No." := LineNo;
        GenJournalLine.SetUpNewLine(GenJournalLine, 0, true);
        GenJournalLine.Validate("Posting Date", RoyaltyStatement."Period End");
        GenJournalLine.Validate("Document No.", RoyaltyStatement."No.");
        GenJournalLine.Validate("Account Type", GenJournalLine."Account Type"::"G/L Account");
        GenJournalLine.Validate("Account No.", AccountNo);
        GenJournalLine.Validate(Amount, Amount);
        GenJournalLine.Validate(Description, CopyStr(StrSubstNo(DescriptionLbl, RoyaltyStatement."Contract No.", RoyaltyStatement."No."), 1, MaxStrLen(GenJournalLine.Description)));
        GenJournalLine.Insert(true);
        exit(1);
    end;

    procedure OpenJournal()
    var
        RoyaltySetup: Record "RYL Royalty Setup";
        GenJournalLine: Record "Gen. Journal Line";
    begin
        RoyaltySetup.Get();
        GenJournalLine.FilterGroup(2);
        GenJournalLine.SetRange("Journal Template Name", RoyaltySetup."Accrual Jnl. Template Name");
        GenJournalLine.SetRange("Journal Batch Name", RoyaltySetup."Accrual Jnl. Batch Name");
        GenJournalLine.FilterGroup(0);
        Page.Run(Page::"General Journal", GenJournalLine);
    end;

    var
        AlreadyPostedErr: Label 'G/L entries with document no. %1 already exist. The accrual for this statement has been posted.', Comment = '%1 = statement no.';
        AlreadyInJournalErr: Label 'Journal lines for statement %1 already exist in batch %2. Post or delete them first.', Comment = '%1 = statement no., %2 = batch name';
        EarnedLbl: Label 'Royalty earned, contract %1, statement %2', Comment = '%1 = contract no., %2 = statement no.';
        RecoupedLbl: Label 'Advance recouped, contract %1, statement %2', Comment = '%1 = contract no., %2 = statement no.';
        PayableLbl: Label 'Royalty payable, contract %1, statement %2', Comment = '%1 = contract no., %2 = statement no.';
}
