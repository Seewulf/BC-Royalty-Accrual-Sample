namespace PrabinBhusal.RoyaltySample;

permissionset 50100 "RYL ROYALTY"
{
    Caption = 'Royalty Accrual Sample';
    Assignable = true;

    Permissions =
        tabledata "RYL Royalty Setup" = RIMD,
        tabledata "RYL Royalty Contract" = RIMD,
        tabledata "RYL Royalty Ledger Entry" = Rim,
        tabledata "RYL Royalty Statement" = RIMD,
        tabledata "RYL Statement Audit Entry" = Ri,
        table "RYL Royalty Setup" = X,
        table "RYL Royalty Contract" = X,
        table "RYL Royalty Ledger Entry" = X,
        table "RYL Royalty Statement" = X,
        table "RYL Statement Audit Entry" = X,
        codeunit "RYL Royalty Calculation" = X,
        codeunit "RYL Statement Management" = X,
        codeunit "RYL Accrual Journal" = X,
        page "RYL Royalty Setup" = X,
        page "RYL Royalty Contracts" = X,
        page "RYL Royalty Contract Card" = X,
        page "RYL Royalty Ledger Entries" = X,
        page "RYL Royalty Statements" = X,
        page "RYL Royalty Statement" = X,
        page "RYL Royalty Statement Lines" = X,
        page "RYL Statement Audit Entries" = X;
}
