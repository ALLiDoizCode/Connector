import Time "mo:base/Time";
import ILPErrorCode "ILPErrorCodes";

module {

    public type Packet = {
        id:Nat8;
        data:PacketType;
    };

    public type PacketType = {
        #Prepare:Prepare;
        #Fulfill:Fulfill;
        #Reject:Reject;
    };

    public type Prepare = {
        amount:Nat64;
        expiresAt:Time.Time;
        destination:Text;
        data:Blob;
    };

    public type Fulfill = {
        data:Blob;
    };

    public type Reject = {
        code:ILPErrorCode.ILPErrorCode;
        triggeredBy:Text;
        message:Text;
        data:Blob;
    };
}