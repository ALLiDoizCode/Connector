import Packet "../models/Packet";

module {

    type Packet = Packet.Packet;
    type Prepare = Packet.Prepare;

    public func service(canister : Text) : actor {
        prepare : shared (Prepare) -> async Packet;
    } {
        return actor (canister) : actor {
            prepare : shared (Prepare) -> async Packet;
        };
    };
};