import Time "mo:base/Time";
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
        code:Text;
        triggeredBy:Text;
        message:Text;
        data:Blob;
    };
}