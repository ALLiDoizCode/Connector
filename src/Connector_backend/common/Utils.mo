import Packet "../models/Packet";
import ILPErrorCodes "../models/ILPErrorCodes";
import Principal "mo:base/Principal";
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

    public func verifyCanister(canister_id:Principal, hash:Blob): async Bool {
        let canister_status = await Canister.CanisterUtils().canisterStatus(canister_id);
        switch(canister_status.module_hash){
            case(?_hash) {
                switch(canister_status.settings.controllers){
                    case(?controllers) _hash == hash and controllers.size() == 0;
                    case(_) _hash == hash
                };
            };
            case(_) false;
        };
    };
};
