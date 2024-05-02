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

  public shared ({ caller }) func commit(amount : Nat) : async [Nat8] {
    // add fee to amount
    let _ = await* _ilpAddress(caller);
    let g = Source.Source();
    let blob = await g.new();
    let uuid = UUID.toText(blob);
    Map.set(commitment, thash, uuid, amount);
    blob;
  };

  public shared ({ caller }) func transfer(txIndex : Nat, packet : Prepare) : async Packet {
    try {
      let ilpAddress = await* _ilpAddress(caller);
      let token = await* _link(ilpAddress);
      var token_address = "";
      switch (token.chain) {
        case (#ICP(canister)) {
          let _ = await _verifyTransaction(caller, txIndex, ?Nat64.toNat(packet.amount), canister);
          token_address := canister;
        };
        case (#BTC(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        case (#ETH(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        case (#SOL(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
      };
      //modify the amount and the time based on the cansiters fee and exchange rate
      let result = await _prepare(caller, packet);
      switch (result.data) {
        case (#Reject(value)) {
          let _ = await _transfer(token_address, Nat64.toNat(packet.amount), Principal.toText(caller));
        };
        case (_) {

        };
      };
      result;
    } catch (e) {
      return Utils.createReject(ILP_Address, Error.message(e), Blob.fromArray([]), ILPErrorCodes.ILP_ERRORS.invalidPacket);
    };
  };

  public shared ({ caller }) func prepare(packet : Prepare) : async Packet {
    //add code to block non peers from making this call
    //add code to allow for a max and min amount
    var to = "";
    var address = "";
    try {
      //get the token associated with the caller aka link
      let token = await* _link(packet.destination);
      let destination = await* _nextHop(packet.destination);
      switch (destination) {
        case (#ICP(principal)) to := principal;
        case (#BTC(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        case (#ETH(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        case (#SOL(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
      };
      switch (token.chain) {
        case (#ICP(canister)) address := canister;
        case (#BTC(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        case (#ETH(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        case (#SOL(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
      };
    } catch (e) {
      return Utils.createReject(ILP_Address, Error.message(e), Blob.fromArray([]), ILPErrorCodes.ILP_ERRORS.invalidPacket);
    };
    let result = await _prepare(caller, packet);
    switch (result.data) {
      case (#FulFill(value)) {
        //transfer token or preform some action and return fulfill packet
        ignore await _transfer(address, Nat64.toNat(packet.amount), to);
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

  private func _prepare(caller : Principal, packet : Prepare) : async Packet {
    if (packet.expiresAt < Time.now()) {
      return Utils.createReject(ILP_Address, "Expired", packet.data, ILPErrorCodes.ILP_ERRORS.timedOut);
    };
    switch (packet.destination) {
      case ("peer.config") await _configureChild(caller, packet);
      case (_) {
        try {
          await _hop(packet);
        } catch (e) {
          return Utils.createReject(ILP_Address, "Peer Not Configured", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        };
      };
    };
  };

  private func _hop(packet : Prepare) : async Packet {
    //if longest prefix is this canister then make transfer to the last segment in the ILPAddress and return a fulfill packet
    try {
      let destination = await* Utils.lastHop(packet.destination, ILP_Address); 
      let token = await* _link(destination);
      switch (token.chain) {
        case (#ICP(canister)) {
          // adjust amount based on fee
          let _ = await _transfer(canister, Nat64.toNat(packet.amount), destination);
          let _packet:Packet = {
            id = 13;
            data = #FulFill({data = packet.data})
          };
          return _packet
        };
        case (#BTC(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        case (#ETH(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
        case (#SOL(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
      };
    } catch (e) {
      //send prepare call to the longest prefix
      let ilpAddress = Utils.getLongestPrefix(packet.destination, Iter.toArray(Map.vals(addresses)));
      switch (ilpAddress) {
        case (?ilpAddress) {
          let hop = await* _nextHop(ilpAddress);
          //query fee for next canister to apply to amount
          //build prepare packet and modify amount and time
          let _packet = {
            amount = packet.amount; //change amount to include fee;
            expiresAt = packet.expiresAt; //reduce time by 5secs to account for consensus;
            destination = packet.destination;
            data = packet.data;
          };
          switch (hop) {
            case (#BTC(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", _packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
            case (#ETH(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", _packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
            case (#ICP(canister)) await ConnectorService.service(canister).prepare(_packet);
            case (#SOL(address)) return Utils.createReject(ILP_Address, "Chain Not Supported", _packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
          };
        };
        case (_) return Utils.createReject(ILP_Address, "Peer Not Configured", packet.data, ILPErrorCodes.ILP_ERRORS.invalidPacket);
      };
    };
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

  private func _transfer(canister : Text, amount : Nat, to : Text) : async ICRC2.TransferResult {
    let _to = { owner = Principal.fromText(to); subaccount = null };
    let fee = await ICRC2.service(canister).icrc1_fee();
    let args = Utils._createTransferArg(_to, ?fee, null, amount, null);
    await ICRC2.service(canister).icrc1_transfer(args);
  };

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
