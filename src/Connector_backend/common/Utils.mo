import Packet "../models/Packet";
import ILPErrorCodes "../models/ILPErrorCodes";

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
};
