import Serializer1xfer "Serializer1xfer";
import Serializer1mint "Serializer1mint";
import Serializer1burn "Serializer1burn";
import Serializer2approve "Serializer2approve";
import Nat64 "mo:base/Nat64";
import D "mo:base/Debug";
import Map "mo:map9/Map";
// This is a generated Motoko binding.
// Please use `import service "ic:canister_id"` instead to call canisters on the IC if possible.


module {
  public type Account = { owner : Principal; subaccount : ?Blob };
  public type Approve = {
    fee : ?Nat;
    from : Account;
    memo : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
    expected_allowance : ?Nat;
    expires_at : ?Nat64;
    spender : Account;
  };
  public type Block = Value;
  public type BlockIndex = Nat;
  public type Burn = {
    from : Account;
    memo : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
    spender : ?Account;
  };
  public type DataCertificate = { certificate : Blob; hash_tree : Blob };
  public type GetArchivesArgs = { from : ?Principal };
  public type GetArchivesResult = [
    { end : Nat; canister_id : Principal; start : Nat }
  ];
  public type GetBlocksArgs = [{ start : Nat; length : Nat }];
  public type GetBlocksResult = {
    log_length : Nat;
    blocks : [{ id : Nat; block : ICRC3Value }];
    archived_blocks : [
      {
        args : GetBlocksArgs;
        callback : shared query GetBlocksArgs -> async GetBlocksResult;
      }
    ];
  };
  public type ICRC3Value = {
    #Int : Int;
    #Map : [(Text, ICRC3Value)];
    #Nat : Nat;
    #Blob : Blob;
    #Text : Text;
    #Array : [ICRC3Value];
  };
  public type Map = [(Text, Value)];
  public type Mint = {
    to : Account;
    memo : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
  };
  public type Transaction = {
    burn : ?Burn;
    kind : Text;
    mint : ?Mint;
    approve : ?Approve;
    timestamp : Nat64;
    transfer : ?Transfer;
  };
  public type Transfer = {
    to : Account;
    fee : ?Nat;
    from : Account;
    memo : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
    spender : ?Account;
  };
  public type Value = {
    #Int : Int;
    #Map : Map;
    #Nat : Nat;
    #Nat64 : Nat64;
    #Blob : Blob;
    #Text : Text;
    #Array : [Value];
  };

  public type Service =  actor {
    append_blocks : shared [Blob] -> async ();
    get_blocks : shared query { start : Nat; length : Nat } -> async {
        blocks : [Block];
      };
    get_transaction : shared query Nat64 -> async ?Transaction;
    get_transactions : shared query { start : Nat; length : Nat } -> async {
        transactions : [Transaction];
      };
    icrc3_get_archives : shared query GetArchivesArgs -> async GetArchivesResult;
    icrc3_get_blocks : shared query GetBlocksArgs -> async GetBlocksResult;
    icrc3_get_tip_certificate : shared query () -> async ?DataCertificate;
    icrc3_supported_block_types : shared query () -> async [
        { url : Text; block_type : Text }
      ];
    remaining_capacity : shared query () -> async Nat64;
  };


  public func blockToTransaction(block: ICRC3Value) : ?Transaction {

    D.print("parsing");

    let #Map(map) = block else return null;
    
    let top : Map.Map<Text, ICRC3Value> = Map.fromIter(map.vals(), Map.thash);

    let ?#Map(txItem) = Map.get(top, Map.thash, "tx") else return null;

    let tx : Map.Map<Text, ICRC3Value> = Map.fromIter(txItem.vals(), Map.thash);

    let op = Map.get(tx, Map.thash, "op");

    let btype = Map.get(top, Map.thash, "btype");

    D.print(debug_show(op, btype));

    let #Text(kindOp) = switch(op, btype){
      case(?val, null) val;
      case(null, ?val) val;
      case(?override, ?val) override;
      case(null, null) return null;
    };

    let ?#Nat(ts) = Map.get(top, Map.thash, "ts") else return null;

    let result : Transaction = if(kindOp == "1mint"){
      {
        burn = null;
        kind = "mint";
        mint = Serializer1mint.parse(block);
        approve = null;
        timestamp = Nat64.fromNat(ts);
        transfer = null;
      } ;
      
    } else if(kindOp == "1burn"){
       {
        burn = Serializer1burn.parse(block);
        kind = "burn";
        mint = null;
        approve = null;
        timestamp = Nat64.fromNat(ts);
        transfer = null;
      } ;
    } else if(kindOp == "1xfer" or kindOp == "2xfer"){
      D.print("found xfer");
      {
        burn = null;
        kind = "transfer";
        mint = null;
        approve = null;
        timestamp = Nat64.fromNat(ts);
        transfer = Serializer1xfer.parse(block);
      };

    } else if(kindOp == "2approve"){
      {
        burn = null;
        kind = "approve";
        mint = null;
        approve = Serializer2approve.parse(block);
        timestamp = Nat64.fromNat(ts);
        transfer = null;
      };
    } else {
      return null;
    };

    ?result;
  };
};