import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Token "models/Token";
import Option "mo:base/Option";
import List "mo:base/List";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Map "mo:map/Map";
import { thash; phash } "mo:map/Map";
actor class Connector(owner:Principal) = this {

  type ILPAddress = Text;
  type Chain = Token.Chain;
  type Token = Token.Token;

  let routingTable = Map.new<ILPAddress, Chain>();
  let addresses = Map.new<Principal, ILPAddress>();
  let links = Map.new<ILPAddress, Token>();
  let tokens = Map.new<Text, Token>();

  public shared ({ caller }) func configureChild(token:Token) : async ILPAddress {
    let isSupported = _isSupported(token.symbol);
    assert(isSupported);
    let _this = Principal.fromActor(this);
    let scheme = "g";
    let separator = ".";
    let parent = Principal.toText(_this);
    let child = Principal.toText(caller);
    let ilpAddress = scheme #separator #parent #separator #child;
    Map.set(routingTable, thash, ilpAddress, #ICP(child));
    Map.set(addresses, phash, caller, ilpAddress);
    Map.set(links, thash, ilpAddress, token);
    ilpAddress;
  };

  public query func ilpAddress(principal : Principal) : async ILPAddress {
    let exist = Map.get(addresses, phash, principal);
    switch (exist) {
      case (?exist) exist;
      case (_) throw (Error.reject("Not Found"));
    };
  };

  public shared({caller}) func setToken(token:Token) : async () {
    assert(caller == owner);
    Map.set(tokens, thash, token.symbol, token);
  };

  private func _isSupported(symbol:Text): Bool {
    let exist = Map.get(tokens,thash,symbol);
    switch(exist){
      case(?exist) true;
      case(_) false;
    };
  };
};
