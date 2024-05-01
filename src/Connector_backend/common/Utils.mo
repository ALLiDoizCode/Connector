import Packet "../models/Packet";
import ILPErrorCodes "../models/ILPErrorCodes";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import List "mo:base/List";
import Canister "../services/Canister";

module {
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
};
