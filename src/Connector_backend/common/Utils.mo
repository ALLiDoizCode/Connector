import Packet "../models/Packet";
import ILPErrorCodes "../models/ILPErrorCodes";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import List "mo:base/List";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Float "mo:base/Float";
import Error "mo:base/Error";
import Canister "../services/Canister";
import ICRC2 "../services/ICRC2";
module {

    private type Account = ICRC2.Account;
    private type TransferArg = ICRC2.TransferArg;
    private type TransferFromArgs = ICRC2.TransferFromArgs;
    private type ApproveArgs = ICRC2.ApproveArgs;
    private type AllowanceArgs = ICRC2.AllowanceArgs;
    private type TransferResult = ICRC2.TransferResult;
    private type TransferFromResult = ICRC2.TransferFromResult;
    private type ApproveResult = ICRC2.ApproveResult;
    private type Allowance = ICRC2.Allowance;

    public func _createTransferArg(to : Account, fee : ?Nat, memo : ?Blob, amount : Nat, from_subaccount : ?Blob) : TransferArg {
        let now = Time.now();
        {
            to = to;
            fee = fee;
            memo = memo;
            from_subaccount = from_subaccount;
            created_at_time = ?Nat64.fromIntWrap(now);
            amount = amount;
        };
    };

    public func _createTransferFromArg(from : Account, to : Account, fee : ?Nat, memo : ?Blob, amount : Nat, spender_subaccount : ?Blob) : TransferFromArgs {
        let now = Time.now();
        {
            spender_subaccount = spender_subaccount;
            from = from;
            to = to;
            amount = amount;
            fee = fee;
            memo = memo;
            created_at_time = ?Nat64.fromIntWrap(now);
        };
    };

    public func _createApproveArg(spender : Account, amount : Nat, fee : ?Nat, memo : ?Blob, expected_allowance : ?Nat, expires_at : ?Nat64, from_subaccount : ?Blob) : ApproveArgs {
        let now = Time.now();
        {
            fee = fee;
            memo = memo;
            from_subaccount = from_subaccount;
            created_at_time = ?Nat64.fromIntWrap(now);
            amount = amount;
            expected_allowance = expected_allowance;
            expires_at = expires_at;
            spender = spender;
        };
    };

    public func _createAllowanceArg(account : Account, spender : Account) : AllowanceArgs {
        {
            account = account;
            spender = spender;
        };
    };

    public func percentage(num:Nat, amount:Nat): Float {
        (Float.fromInt(num) / Float.fromInt(amount)) * 100;
    };

    public func isValidILPAddress(address : Text) : Bool {
        // Define the ILP address pattern
        let pattern = "(?=^.{1,1023}$)^(g|private|example|peer|self|test[1-3]?|local)([.][a-zA-Z0-9_~-]+)+$";
        true;
    };

    public func createReject(triggeredBy : Text, message : Text, data : Blob, error : ILPErrorCodes.ILPErrorCode) : Packet.Packet {
        let reject = {
            code = error;
            triggeredBy = triggeredBy;
            message = message;
            data = data;
        };
        return {
            id = 14;
            data = #Reject(reject);
        };
    };

    public func verifyCanister(canister_id : Principal, hash : Blob) : async Bool {
        let canister_status = await Canister.CanisterUtils().canisterStatus(canister_id);
        switch (canister_status.module_hash) {
            case (?_hash) {
                switch (canister_status.settings.controllers) {
                    case (?controllers) _hash == hash and controllers.size() == 0;
                    case (_) _hash == hash;
                };
            };
            case (_) false;
        };
    };

    public func longestmatch(match:List.List<Text>,values:List.List<Text>) : Nat {
        var count = 0;
        let _match = List.pop(match);
        let _values = List.pop(values);
        
        switch(_match.0,_values.0){
            case(?a,?b) if(a == b) count := count + 1;
            case(_) {
                return count
            };
        };
        count := count + longestmatch(_match.1,_values.1);
        count
    };

    public func getLongestPrefix(match:Text,values:[Text]) : ?Text {
        var count = 0;
        var result:?Text = null;
        let _match = Iter.toArray(Text.tokens(match, #text(".")));
        for(value in values.vals()){
            let _value = Iter.toArray(Text.tokens(value, #text(".")));
            let _count = longestmatch(List.fromArray(_match),List.fromArray(_value));
            if(_count > count) result := ?value;
        };
        result
    };

    public func lastHop(destination:Text,ilpAddress:Text) : async* Text {
        let _destination = Iter.toArray(Text.tokens(destination, #text(".")));
        let size = _destination.size();
        if(_destination.size() > 1){
             let _ilpAddress = _destination[size - 2];
             if(_ilpAddress == ilpAddress) return _destination[size - 1];
             throw(Error.reject(""))
        }else{
            throw(Error.reject(""))
        }
    };
};
