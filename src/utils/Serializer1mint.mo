import Map "mo:map9/Map";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";

module {



  public type Account = { owner : Principal; subaccount : ?Blob };

  public type Mint = {
    to : Account;
    memo : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
  };

  public type ICRC3Value = {
    #Int : Int;
    #Map : [(Text, ICRC3Value)];
    #Nat : Nat;
    #Blob : Blob;
    #Text : Text;
    #Array : [ICRC3Value];
  };

  public func parse(block: ICRC3Value) : ?Mint {

    let #Map(map) = block else return null;
    
    let top : Map.Map<Text, ICRC3Value> = Map.fromIter(map.vals(), Map.thash);

    let ?#Map(opItem) = Map.get(top, Map.thash, "tx") else return null;

    let tx : Map.Map<Text, ICRC3Value> = Map.fromIter(opItem.vals(), Map.thash);

    let ?#Text(btype) = Map.get(top, Map.thash, "btype") else return null;

    if(btype == "1mint"){

      //parse to
      let ?#Array(toArray) = Map.get(tx, Map.thash, "to") else return null;
      let to = if(toArray.size() == 0){
        return null;
      } else if(toArray.size() == 1){
        let #Blob(principal) = toArray[0] else return null;
        {
          owner = Principal.fromBlob(principal);
          subaccount = null;
        };
      } else {
        let #Blob(principal) = toArray[0] else return null;
        let #Blob(subaccount) = toArray[1] else return null;
        {
          owner = Principal.fromBlob(principal);
          subaccount = ?subaccount;
        };
      };

      

      //parse memo
      let topMemo = Map.get(top, Map.thash, "memo");
      let opMemo = Map.get(tx, Map.thash, "memo");

      let memo = switch(topMemo, opMemo){
        case(null, ?#Blob(val)) ?val;
        case(?#Blob(val), null) ?val;
        case(?#Blob(val), ?#Blob(override)) ?override;
        case(_) null;
      };

      //created_at_time memo
      let opTs = Map.get(tx, Map.thash, "ts");

      let ts = switch(opTs){
        case(?#Nat(val)) ?Nat64.fromNat(val);
        case(_) null;
      };

      //created_at_time memo
      let ?#Nat(amount) = Map.get(tx, Map.thash, "amount") else return null;

      

      ?{
        to = to;
        memo = memo;
        created_at_time = ts;
        amount = amount;
      };

    } else return null;
  };

};