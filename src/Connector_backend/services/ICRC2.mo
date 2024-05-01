import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";

module {

    public type Account = { owner : Principal; subaccount : ?Blob };
    public type Allowance = { allowance : Nat; expires_at : ?Nat64 };
    public type AllowanceArgs = { account : Account; spender : Account };
    public type Approve = {
        fee : ?Nat;
        from : Account;
        memo : ?Blob;
        created_at_time : ?Nat64;
        amount : Nat;
        expected_allowance : ?Nat;
        expires_at : ?Nat64;
        spender : Account;
    };
    public type ApproveArgs = {
        fee : ?Nat;
        memo : ?Blob;
        from_subaccount : ?Blob;
        created_at_time : ?Nat64;
        amount : Nat;
        expected_allowance : ?Nat;
        expires_at : ?Nat64;
        spender : Account;
    };
    public type ApproveError = {
        #GenericError : { message : Text; error_code : Nat };
        #TemporarilyUnavailable;
        #Duplicate : { duplicate_of : Nat };
        #BadFee : { expected_fee : Nat };
        #AllowanceChanged : { current_allowance : Nat };
        #CreatedInFuture : { ledger_time : Nat64 };
        #TooOld;
        #Expired : { ledger_time : Nat64 };
        #InsufficientFunds : { balance : Nat };
    };
    public type ArchivedRange = {
        callback : shared query GetBlocksRequest -> async { blocks : [Value] };
        start : Nat;
        length : Nat;
    };
    public type ArchivedRange_1 = {
        callback : shared query GetBlocksRequest -> async {
            transactions : [Transaction];
        };
        start : Nat;
        length : Nat;
    };
    public type Burn = {
        from : Account;
        memo : ?Blob;
        created_at_time : ?Nat64;
        amount : Nat;
    };
    public type DataCertificate = { certificate : ?Blob; hash_tree : Blob };
    public type GetBlocksRequest = { start : Nat; length : Nat };
    public type GetBlocksResponse = {
        certificate : ?Blob;
        first_index : Nat;
        blocks : [Value];
        chain_length : Nat64;
        archived_blocks : [ArchivedRange];
    };
    public type GetTransactionsResponse = {
        first_index : Nat;
        log_length : Nat;
        transactions : [Transaction];
        archived_transactions : [ArchivedRange_1];
    };
    public type HttpRequest = {
        url : Text;
        method : Text;
        body : Blob;
        headers : [(Text, Text)];
    };
    public type HttpResponse = {
        body : Blob;
        headers : [(Text, Text)];
        status_code : Nat16;
    };
    public type MetadataValue = {
        #Int : Int;
        #Nat : Nat;
        #Blob : Blob;
        #Text : Text;
    };
    public type Mint = {
        to : Account;
        memo : ?Blob;
        created_at_time : ?Nat64;
        amount : Nat;
    };
    public type TransferResult = { #Ok : Nat; #Err : TransferError };
    public type ApproveResult = { #Ok : Nat; #Err : ApproveError };
    public type TransferFromResult = { #Ok : Nat; #Err : TransferFromError };
    public type StandardRecord = { url : Text; name : Text };
    public type Transaction = {
        burn : ?Burn;
        kind : Text;
        mint : ?Mint;
        approve : ?Approve;
        timestamp : Nat64;
        transfer_from : ?TransferFrom;
        transfer : ?Transfer;
    };
    public type Transfer = {
        to : Account;
        fee : ?Nat;
        from : Account;
        memo : ?Blob;
        created_at_time : ?Nat64;
        amount : Nat;
    };
    public type TransferArg = {
        to : Account;
        fee : ?Nat;
        memo : ?Blob;
        from_subaccount : ?Blob;
        created_at_time : ?Nat64;
        amount : Nat;
    };
    public type TransferError = {
        #GenericError : { message : Text; error_code : Nat };
        #TemporarilyUnavailable;
        #BadBurn : { min_burn_amount : Nat };
        #Duplicate : { duplicate_of : Nat };
        #BadFee : { expected_fee : Nat };
        #CreatedInFuture : { ledger_time : Nat64 };
        #TooOld;
        #InsufficientFunds : { balance : Nat };
    };

    public type TransferFromError = {
        #BadFee : { expected_fee : Nat };
        #BadBurn : { min_burn_amount : Nat };
        // The [from] account does not hold enough funds for the transfer.
        #InsufficientFunds : { balance : Nat };
        // The caller exceeded its allowance.
        #InsufficientAllowance : { allowance : Nat };
        #TooOld;
        #CreatedInFuture : { ledger_time : Nat64 };
        #Duplicate : { duplicate_of : Nat };
        #TemporarilyUnavailable;
        #GenericError : { error_code : Nat; message : Text };
    };

    public type TransferFromArgs = {
        spender_subaccount : ?Blob;
        from : Account;
        to : Account;
        amount : Nat;
        fee : ?Nat;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    public type TransferFrom = {
        to : Account;
        fee : ?Nat;
        from : Account;
        memo : ?Blob;
        created_at_time : ?Nat64;
        amount : Nat;
        spender : Account;
    };
    public type Value = {
        #Int : Int;
        #Map : [(Text, Value)];
        #Nat : Nat;
        #Nat64 : Nat64;
        #Blob : Blob;
        #Text : Text;
        #Array : Vec;
    };
    public type Vec = [
        {
            #Int : Int;
            #Map : [(Text, Value)];
            #Nat : Nat;
            #Nat64 : Nat64;
            #Blob : Blob;
            #Text : Text;
            #Array : Vec;
        }
    ];

    public func service(canister : Text) : actor {
        get_blocks : shared query GetBlocksRequest -> async GetBlocksResponse;
        get_data_certificate : shared query () -> async DataCertificate;
        get_transactions : shared query GetBlocksRequest -> async GetTransactionsResponse;
        get_transaction : shared query Nat -> async ?Transaction;
        http_request : shared query HttpRequest -> async HttpResponse;
        icrc1_balance_of : shared query Account -> async Nat;
        icrc1_decimals : shared query () -> async Nat8;
        icrc1_fee : shared query () -> async Nat;
        icrc1_metadata : shared query () -> async [(Text, MetadataValue)];
        icrc1_minting_account : shared query () -> async ?Account;
        icrc1_name : shared query () -> async Text;
        icrc1_supported_standards : shared query () -> async [StandardRecord];
        icrc1_symbol : shared query () -> async Text;
        icrc1_total_supply : shared query () -> async Nat;
        icrc1_transfer : shared TransferArg -> async TransferResult;
        icrc2_transfer_from : shared TransferFromArgs -> async TransferFromResult;
        icrc2_allowance : shared query AllowanceArgs -> async Allowance;
        icrc2_approve : shared ApproveArgs -> async ApproveResult;
    } {
        return actor (canister) : actor {
            get_blocks : shared query GetBlocksRequest -> async GetBlocksResponse;
            get_data_certificate : shared query () -> async DataCertificate;
            get_transactions : shared query GetBlocksRequest -> async GetTransactionsResponse;
            get_transaction : shared query Nat -> async ?Transaction;
            http_request : shared query HttpRequest -> async HttpResponse;
            icrc1_balance_of : shared query Account -> async Nat;
            icrc1_decimals : shared query () -> async Nat8;
            icrc1_fee : shared query () -> async Nat;
            icrc1_metadata : shared query () -> async [(Text, MetadataValue)];
            icrc1_minting_account : shared query () -> async ?Account;
            icrc1_name : shared query () -> async Text;
            icrc1_supported_standards : shared query () -> async [StandardRecord];
            icrc1_symbol : shared query () -> async Text;
            icrc1_total_supply : shared query () -> async Nat;
            icrc1_transfer : shared TransferArg -> async TransferResult;
            icrc2_transfer_from : shared TransferFromArgs -> async TransferFromResult;
            icrc2_allowance : shared query AllowanceArgs -> async Allowance;
            icrc2_approve : shared ApproveArgs -> async ApproveResult;
        };
    };
};