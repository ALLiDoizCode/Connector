import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Token "models/Token";
import Option "mo:base/Option";
import List "mo:base/List";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Time "mo:base/Time";
import Blob "mo:base/Blob";
import Map "mo:map/Map";
import { thash; phash } "mo:map/Map";
import Packet "models/Packet";
import ILPErrorCodes "models/ILPErrorCodes";
import ICRC2 "./services/ICRC2";
import Source "mo:uuid/async/SourceV4";
import UUID "mo:uuid/UUID";
import Utils "common/Utils";
import ConnectorService "services/Connector";

actor class Connector(owner : Principal) = this {

  type ILPAddress = Text;
  type Chain = Token.Chain;
  type Token = Token.Token;
  type Packet = Packet.Packet;
  type PacketType = Packet.PacketType;
  type Prepare = Packet.Prepare;
  type FulFill = Packet.FulFill;
  type Reject = Packet.Reject;

  stable let routingTable = Map.new<ILPAddress, Chain>();
  stable let addresses = Map.new<Principal, ILPAddress>();
  stable let links = Map.new<ILPAddress, Token>();
  stable let tokens = Map.new<Text, Token>();
  stable let fulfillment = Map.new<Text, ICRC2.TransferArg>();
  stable let commitment = Map.new<Text, Nat>();
  stable var ILP_Address = "";

  public shared ({ caller }) func prepare(packet : Prepare) : async Packet {
    let result = await _prepare(caller, packet);
    switch(result.data){
      case(#FulFill(value)){
        //transfers funds
        //let token = await* _link(value.destination);
        result
      };
      case(_){
        result
      };
    };
  };

  private func _prepare(caller : Principal, value : Prepare) : async Packet {
    var address = "";
    try {
      address := await* _ilpAddress(caller);
    } catch (e) {
      return Utils.createReject(ILP_Address, Error.message(e), value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
    };
    if (value.expiresAt < Time.now()) {
      return Utils.createReject(ILP_Address, "Expired", value.data, ILPErrorCodes.ILP_ERRORS.timedOut);
    };
    switch (value.destination) {
      case ("peer.config") await _configureChild(caller, value);
      case (_) {
        try {
          //get longest prefix if ILPAddress isn't this canister
          //build prepare packet and modify amount and time
          //send prepare call to the longest prefix if ILPAddress isn't this cansiter
          //if response packet is fulfill then transfer token or preform some action and return fulfill packet
          //if response packet is a reject packet don't preform any actions and return reject packet
          let fulfill:Packet = {
            id = 13;
            data = #FulFill({data = Blob.fromArray([])})
          };
          return fulfill
        } catch (e) {
          return Utils.createReject(ILP_Address, "Peer Not Configured", value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        };
      };
    };
  };

  private func _configureChild(caller : Principal, value : Prepare) : async Packet {
    switch (Text.decodeUtf8(value.data)) {
      case (?symbol) {
        let isSupported = _isSupported(symbol);
        if (isSupported == false) {
          return Utils.createReject(ILP_Address, "Token Not Supported", value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        };
        let exist = Map.get(tokens, thash, symbol);
        switch (exist) {
          case (?token) {
            let _this = Principal.fromActor(this);
            let scheme = "g";
            let separator = ".";
            let parent = Principal.toText(_this);
            let child = Principal.toText(caller);
            let ilpAddress = scheme #separator #parent #separator #child;
            Map.set(routingTable, thash, ilpAddress, #ICP(child));
            Map.set(addresses, phash, caller, ilpAddress);
            Map.set(links, thash, ilpAddress, token);
            let data = Text.encodeUtf8(ilpAddress);
            return {
              id = 13;
              data = #FulFill({ data = data });
            };
          };
          case (_) {
            return Utils.createReject(ILP_Address, "Token Not Supported", value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
          };
        };
      };
      case (_) {
        let reject = {
          code = ILPErrorCodes.ILP_ERRORS.invalidPacket;
          triggeredBy = ILP_Address;
          message = "Data Field Is Invalid";
          data = value.data;
        };
        return {
          id = 14;
          data = #Reject(reject);
        };
      };
    };
  };

  public query func ilpAddress(caller : Principal) : async ILPAddress {
    let exist = Map.get(addresses, phash, caller);
    switch (exist) {
      case (?exist) exist;
      case (_) throw (Error.reject("Not Found"));
    };
  };

  public shared ({ caller }) func setToken(token : Token) : async () {
    assert (caller == owner);
    Map.set(tokens, thash, token.symbol, token);
  };

  private func _ilpAddress(caller : Principal) : async* ILPAddress {
    let exist = Map.get(addresses, phash, caller);
    switch (exist) {
      case (?exist) exist;
      case (_) throw (Error.reject("Not Found"));
    };
  };

  private func _link(address : ILPAddress) : async* Token {
    let exist = Map.get(links, thash, address);
    switch (exist) {
      case (?exist) exist;
      case (_) throw (Error.reject("Not Found"));
    };
  };

  private func _isSupported(symbol : Text) : Bool {
    let exist = Map.get(tokens, thash, symbol);
    switch (exist) {
      case (?exist) true;
      case (_) false;
    };
  };

  /*public shared func commit(amount : Nat) : async [Nat8] {
    let g = Source.Source();
    let blob = await g.new();
    let uuid = UUID.toText(blob);
    Map.set(commitment, thash, uuid, amount);
    blob;
  };

  public shared({caller}) func transfer(txIndex : Nat, amount : Nat, destination:Text, token : Text) : async () {
    let amount = await _verifyTransaction(caller, txIndex, ?amount, token);
  };*/

  /*private func _verifyTransaction(caller : Principal, txIndex : Nat, amount : ?Nat, token : Text) : async Nat {
    var committedAmount = 0;
    let from : ICRC2.Account = { owner = caller; subaccount = null };
    let to : ICRC2.Account = {
      owner = Principal.fromActor(this);
      subaccount = null;
    };
    let transaction : ?ICRC2.Transaction = await ICRC2.service(token).get_transaction(txIndex);
    switch (transaction) {
      case (?transaction) {
        switch (transaction.transfer) {
          case (?transfer) {
            switch (transfer.memo) {
              case (?memo) {
                let uuid = UUID.toText(Blob.toArray(memo));
                let _amount = Map.get(commitment, thash, uuid);
                switch (_amount) {
                  case (?_amount) {
                    switch (amount) {
                      case (?amount) {
                        if (transfer.to == to and transfer.from == from and transfer.amount >= amount) {
                          Map.delete(commitment, thash, uuid);
                          committedAmount := _amount;
                        } else {
                          throw (Error.reject("Insuffient Transaction"));
                        };
                      };
                      case (_) {
                        if (transfer.to == to and transfer.from == from and transfer.amount >= _amount) {
                          Map.delete(commitment, thash, uuid);
                          committedAmount := _amount;
                        } else {
                          throw (Error.reject("Insuffient Transaction"));
                        };
                      };
                    };
                  };
                  case (_) {
                    throw (Error.reject("Commitment Not Found"));
                  };
                };
              };
              case (_) {
                throw (Error.reject("Memo Not Found"));
              };
            };
          };
          case (_) {
            throw (Error.reject("Incorrect Transaction Type"));
          };
        };
      };
      case (_) {
        throw (Error.reject("Transaction Not Found"));
      };
    };
    committedAmount;
  };*/
};
