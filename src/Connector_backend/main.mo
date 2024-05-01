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
import Nat64 "mo:base/Nat64";
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
  stable let commitment = Map.new<Text, Nat>();
  stable var ILP_Address = "";
  stable var wasm_hash = Blob.fromArray([]);


  public shared func commit(amount : Nat) : async [Nat8] {
    let g = Source.Source();
    let blob = await g.new();
    let uuid = UUID.toText(blob);
    Map.set(commitment, thash, uuid, amount);
    blob;
  };

  public shared ({ caller }) func transfer(txIndex : Nat, value:Prepare) : async Packet {
    try {
      let ilpAddress = await* _ilpAddress(caller);
      let token = await* _link(ilpAddress);
      switch(token.chain){
        case(#ICP(canister)) let _ = await _verifyTransaction(caller, txIndex, ?Nat64.toNat(value.amount), canister);
        case(#BTC(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        case(#ETH(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        case(#SOL(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
      };
      //modify the amount and the time based on the cansiters fee and exchange rate
      await _prepare(caller, value)
    } catch (e) {
      return Utils.createReject(ILP_Address, Error.message(e), Blob.fromArray([]), ILPErrorCodes.ILP_ERRORS.invalidPacket);
    };
  };

  public shared ({ caller }) func prepare(packet : Prepare) : async Packet {
    //get the token associated with the caller aka link
    //make a tranferFrom call or equavalent
    //if successful create a prepare packet
    //let token = await* _link(value.destination);
    let result = await _prepare(caller, packet);
    switch (result.data) {
      case (#FulFill(value)) {
        //if response packet is fulfill get the token associated with the caller aka link
        //then transfer token or preform some action and return fulfill packet
        //let token = await* _link(value.destination);
        result;
      };
      case (_) {
        //if response packet is a reject packet don't preform any actions and return reject packet
        result;
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

  private func _prepare(caller : Principal, value : Prepare) : async Packet {
    if (value.expiresAt < Time.now()) {
      return Utils.createReject(ILP_Address, "Expired", value.data, ILPErrorCodes.ILP_ERRORS.timedOut);
    };
    switch (value.destination) {
      case ("peer.config") await _configureChild(caller, value);
      case (_) {
        try {
          await _hop(value);
        } catch (e) {
          return Utils.createReject(ILP_Address, "Peer Not Configured", value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        };
      };
    };
  };

  private func _hop(value : Prepare) : async Packet {
    //get longest prefix if ILPAddress isn't this canister
    //build prepare packet and modify amount and time
    //send prepare call to the longest prefix if ILPAddress isn't this cansiter
    let ilpAddress = Utils.getLongestPrefix(value.destination, Iter.toArray(Map.vals(addresses)));
    switch (ilpAddress) {
      case (?ilpAddress) {
        let hop = await* _nextHop(ilpAddress);
        switch (hop) {
          case (#BTC(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
          case (#ETH(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
          case (#ICP(address)) await _icpHop(address);
          case (#SOL(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        };
      };
      case (_) return Utils.createReject(ILP_Address, "Peer Not Configured", value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
    };
  };

  private func _icpHop(canister : Text) : async Packet {
    // modify amount and time if needed
    let preparePacket : Prepare = {
      amount = 0;
      expiresAt = Time.now();
      destination = "";
      data = Blob.fromArray([]);
    };
    await ConnectorService.service(canister : Text).prepare(preparePacket);
  };

  private func _configureChild(caller : Principal, value : Prepare) : async Packet {
    let isConnector = await Utils.verifyCanister(caller, wasm_hash);
    if (isConnector == false) return Utils.createReject(ILP_Address, "wasm module is not correct or controllers listed is not blackholed", value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
    switch (Text.decodeUtf8(value.data)) {
      case (?symbol) {
        let isSupported = _isSupported(symbol);
        if (isSupported == false) {
          return Utils.createReject(ILP_Address, "Token Not Supported", value.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        };
        let exist = Map.get(tokens, thash, symbol);
        switch (exist) {
          case (?token) {
            let data = _createChild(caller, token);
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

  private func _ilpAddress(caller : Principal) : async* ILPAddress {
    let exist = Map.get(addresses, phash, caller);
    switch (exist) {
      case (?exist) exist;
      case (_) throw (Error.reject("Not Found"));
    };
  };

  private func _nextHop(value : ILPAddress) : async* Chain {
    let exist = Map.get(routingTable, thash, value);
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

  private func _createChild(caller : Principal, token : Token) : Blob {
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
    data;
  };

  /*public shared({caller}) func transfer(txIndex : Nat, amount : Nat, destination:Text, token : Text) : async () {
    let amount = await _verifyTransaction(caller, txIndex, ?amount, token);
  };*/

  private func _verifyTransaction(caller : Principal, txIndex : Nat, amount : ?Nat, token : Text) : async Nat {
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
  };
};
