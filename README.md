# icrc3.mo

## Install
```
mops add icrc3.mo
```

## Usage
```motoko
import ICRC3 "mo:icrc3.mo";

// example...
```
  func icrc3() : ICRC3.ICRC3 {
    switch(_icrc3){
      case(null){
        let initclass : ICRC3.ICRC3 = ICRC3.ICRC3(?icrc3_state_current, Principal.fromActor(this), get_icrc3_environment());
        _icrc3 := ?initclass;
        initclass;
      };
      case(?val) val;
    };
  };

  public query func icrc3_get_blocks(args: ICRC3MigrationTypes.Current.TransactionRange) : async ICRC3MigrationTypes.Current.GetTransactionsResult{
    return icrc3().get_transactions(args);
  };

  public shared(msg) func addUser(user: (Principal, Text)) : async Nat {

    return icrc3().add_record(#Map([
      ("op", #Text("icrc_u_update_user")),
      ("principal", #Blob(Principal.toBlob(user.0))),
      ("username", #Text(user.1)),
      ("timestamp", #Int(get_time())),
      ("caller", #Blob(Principal.toBlob(msg.caller)))
    ]), null);
  };
```