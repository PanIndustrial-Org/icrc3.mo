import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Map "mo:map9/Map";

module {



  public type Account = { owner : Principal; subaccount : ?Blob };

  public type Burn = {
    from : Account;
    memo : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
    spender : ?Account;
  };

  public type ICRC3Value = {
    #Int : Int;
    #Map : [(Text, ICRC3Value)];
    #Nat : Nat;
    #Blob : Blob;
    #Text : Text;
    #Array : [ICRC3Value];
  };

  public func parse(block: ICRC3Value) : ?Burn {

    let #Map(map) = block else return null;
    
    let top : Map.Map<Text, ICRC3Value> = Map.fromIter(map.vals(), Map.thash);

    let ?#Map(opItem) = Map.get(top, Map.thash, "tx") else return null;

    let tx : Map.Map<Text, ICRC3Value> = Map.fromIter(opItem.vals(), Map.thash);

    let ?#Text(btype) = Map.get(top, Map.thash, "btype") else return null;

    if(btype == "1burn"){

      

      //parse from
      let ?#Array(fromArray) = Map.get(tx, Map.thash, "from") else return null;
      let from = if(fromArray.size() == 0){
        return null;
      } else if(fromArray.size() == 1){
        let #Blob(principal) = fromArray[0] else return null;
        {
          owner = Principal.fromBlob(principal);
          subaccount = null;
        };
      } else {
        let #Blob(principal) = fromArray[0] else return null;
        let #Blob(subaccount) = fromArray[1] else return null;
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

      //parse spender
      let spenderItem = Map.get(tx, Map.thash, "spender");

      let spender : ?Account = switch(spenderItem){
        case(?#Array(spenderArray)){
          if(spenderArray.size() == 0){
            null;
          } else if(spenderArray.size() == 1){
            let #Blob(principal) = spenderArray[0] else return null;
            ?{
              owner = Principal.fromBlob(principal);
              subaccount = null;
            };
          } else {
            let #Blob(principal) = spenderArray[0] else return null;
            let #Blob(subaccount) = spenderArray[1] else return null;
            ?{
              owner = Principal.fromBlob(principal);
              subaccount = ?subaccount;
            };
          };
        };
        case(_) null;
      };

      ?{
        from = from;
        spender = spender;
        memo = memo;
        created_at_time = ts;
        amount = amount;
      };

    } else return null;
  };

};