import Map "mo:map9/Map";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import D "mo:base/Debug";

module {



  public type Account = { owner : Principal; subaccount : ?Blob };

  public type Transfer = {
    to : Account;
    fee : ?Nat;
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

  public func parse(block: ICRC3Value) : ?Transfer {

    D.print("parsing xfer");

    let #Map(map) = block else return null;
    
    let top : Map.Map<Text, ICRC3Value> = Map.fromIter(map.vals(), Map.thash);

    let ?#Map(opItem) = Map.get(top, Map.thash, "tx") else return null;

    let tx : Map.Map<Text, ICRC3Value> = Map.fromIter(opItem.vals(), Map.thash);

    let ?#Text(btype) = Map.get(top, Map.thash, "btype") else return null;

    D.print(debug_show((map, opItem, tx)));

    if(btype == "1xfer" or btype == "2xfer"){

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
      D.print("to " # debug_show(to));

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

      D.print("from " # debug_show(from));

      //parse fee
      let topFee = Map.get(top, Map.thash, "fee");
      let opFee = Map.get(tx, Map.thash, "fee");

      let fee = switch(topFee, opFee){
        case(null, ?#Nat(val)) ?val;
        case(?#Nat(val), null) ?val;
        case(?#Nat(val), ?#Nat(override)) ?override;
        case(_) null;
      };

      D.print("fee " # debug_show(fee));

      //parse memo
      let topMemo = Map.get(top, Map.thash, "memo");
      let opMemo = Map.get(tx, Map.thash, "memo");

      let memo = switch(topMemo, opMemo){
        case(null, ?#Blob(val)) ?val;
        case(?#Blob(val), null) ?val;
        case(?#Blob(val), ?#Blob(override)) ?override;
        case(_) null;
      };

      D.print("memo " # debug_show(memo));

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
        to = to;
        from = from;
        fee = fee;
        memo = memo;
        created_at_time = ts;
        amount = amount;
        spender = spender;
      };

    } else return null;
  };

};