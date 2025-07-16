import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";

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
  public type GetBlocksArgs = { start : Nat; length : Nat };
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

  public type GetBlocksRequest = { start : Nat; length : Nat };

  public type GetTransactionsResponse = {
    first_index : Nat;
    log_length : Nat;
    transactions : [Transaction];
    archived_transactions : [LegacyArchivedRange];
  };

  public type GetArchiveTransactionsResponse = {
    
    transactions : [Transaction];
  };

  public type LegacyArchivedRange = {
    callback : GetLegacyArchiveTransactionFunction;
    start : Nat;
    length : Nat;
  };

  public type GetLegacyTransactionFunction = shared query GetBlocksRequest -> async GetTransactionsResponse;

   public type GetLegacyArchiveTransactionFunction = shared query GetBlocksRequest -> async GetArchiveTransactionsResponse;




  public func convertICRC3ToLegacyTransaction(items: [Value]) : [Transaction] {
    let transactions = Buffer.Buffer<Transaction>(items.size());
    
    for (item in items.vals()) {
      switch (item) {
        case (#Map(blockMap)) {
          // Extract timestamp from top-level "ts" field
          let timestamp : Nat64 = switch (getMapValue(blockMap, "ts")) {
            case (?#Nat(ts)) Nat64.fromNat(ts);
            case (_) 0 : Nat64; // Default timestamp if not found
          };
          
          // Extract transaction data from "tx" field
          switch (getMapValue(blockMap, "tx")) {
            case (?#Map(txMap)) {
              // Get operation type with multiple fallback strategies:
              // 1. First check tx.op field (most common for ICRC-1/ICRC-2)
              // 2. Then check block-level btype field (ICRC-3 standard)
              // 3. Finally default to "unknown"
              let opType = switch (getMapValue(txMap, "op")) {
                case (?#Text(op)) op;
                case (_) {
                  // Fallback to btype at block level
                  switch (getMapValue(blockMap, "btype")) {
                    case (?#Text(btype)) btype;
                    case (_) "unknown";
                  };
                };
              };
              
              let transaction = convertSingleTransaction(txMap, blockMap, opType, timestamp);
              transactions.add(transaction);
            };
            case (_) {
              // Handle case where there's no "tx" field - create default transaction
              let transaction : Transaction = {
                burn = null;
                kind = "unknown";
                mint = null;
                approve = null;
                timestamp = timestamp : Nat64;
                transfer = null;
              };
              transactions.add(transaction);
            };
          };
        };
        case (_) {
          // Handle non-Map values - create default transaction
          let transaction : Transaction = {
            burn = null;
            kind = "unknown";
            mint = null;
            approve = null;
            timestamp = 0;
            transfer = null;
          };
          transactions.add(transaction);
        };
      };
    };
    
    Buffer.toArray(transactions);
  };

  private func convertSingleTransaction(txMap: [(Text, Value)], blockMap: [(Text, Value)], opType: Text, timestamp: Nat64) : Transaction {
    let kind = switch (opType) {
      case ("mint" or "1mint") "mint";
      case ("burn" or "1burn") "burn";
      case ("xfer" or "1xfer" or "2xfer") "transfer";
      case ("approve" or "2approve") "approve";
      case (_) opType;
    };
    
    switch (kind) {
      case ("mint") {
        {
          burn = null;
          kind = "mint";
          mint = ?{
            to = extractAccount(txMap, "to");
            memo = extractMemo(txMap);
            created_at_time = extractCreatedAtTime(txMap);
            amount = extractAmount(txMap);
          };
          approve = null;
          timestamp = timestamp;
          transfer = null;
        };
      };
      case ("burn") {
        {
          burn = ?{
            from = extractAccount(txMap, "from");
            memo = extractMemo(txMap);
            created_at_time = extractCreatedAtTime(txMap);
            amount = extractAmount(txMap);
            spender = extractOptionalAccount(txMap, "spender");
          };
          kind = "burn";
          mint = null;
          approve = null;
          timestamp = timestamp;
          transfer = null;
        };
      };
      case ("transfer") {
        {
          burn = null;
          kind = "transfer";
          mint = null;
          approve = null;
          timestamp = timestamp;
          transfer = ?{
            to = extractAccount(txMap, "to");
            fee = extractFee(txMap, blockMap);
            from = extractAccount(txMap, "from");
            memo = extractMemo(txMap);
            created_at_time = extractCreatedAtTime(txMap);
            amount = extractAmount(txMap);
            spender = extractOptionalAccount(txMap, "spender");
          };
        };
      };
      case ("approve") {
        {
          burn = null;
          kind = "approve";
          mint = null;
          approve = ?{
            fee = extractFee(txMap, blockMap);
            from = extractAccount(txMap, "from");
            memo = extractMemo(txMap);
            created_at_time = extractCreatedAtTime(txMap);
            amount = extractAmount(txMap);
            expected_allowance = extractOptionalNat(txMap, "expected_allowance");
            expires_at = extractOptionalNat64(txMap, "expires_at");
            spender = extractAccount(txMap, "spender");
          };
          timestamp = timestamp;
          transfer = null;
        };
      };
      case (_) {
        {
          burn = null;
          kind = kind;
          mint = null;
          approve = null;
          timestamp = timestamp;
          transfer = null;
        };
      };
    };
  };

  private func getMapValue(map: [(Text, Value)], key: Text) : ?Value {
    for ((k, v) in map.vals()) {
      if (k == key) return ?v;
    };
    null;
  };

  private func extractAccount(txMap: [(Text, Value)], field: Text) : Account {
    switch (getMapValue(txMap, field)) {
      case (?#Array(arr)) {
        switch (arr.size()) {
          case (1) {
            switch (arr[0]) {
              case (#Blob(ownerBlob)) {
                {
                  owner = Principal.fromBlob(ownerBlob);
                  subaccount = null;
                };
              };
              case (_) {
                {
                  owner = Principal.fromText("2vxsx-fae");
                  subaccount = null;
                };
              };
            };
          };
          case (2) {
            let owner = switch (arr[0]) {
              case (#Blob(ownerBlob)) Principal.fromBlob(ownerBlob);
              case (_) Principal.fromText("2vxsx-fae");
            };
            let subaccount = switch (arr[1]) {
              case (#Blob(subBlob)) ?subBlob;
              case (_) null;
            };
            { owner = owner; subaccount = subaccount };
          };
          case (_) {
            {
              owner = Principal.fromText("2vxsx-fae");
              subaccount = null;
            };
          };
        };
      };
      case (_) {
        {
          owner = Principal.fromText("2vxsx-fae");
          subaccount = null;
        };
      };
    };
  };

  private func extractOptionalAccount(txMap: [(Text, Value)], field: Text) : ?Account {
    switch (getMapValue(txMap, field)) {
      case (?value) ?extractAccountFromValue(value);
      case (null) null;
    };
  };

  private func extractAccountFromValue(value: Value) : Account {
    switch (value) {
      case (#Array(arr)) {
        switch (arr.size()) {
          case (1) {
            switch (arr[0]) {
              case (#Blob(ownerBlob)) {
                {
                  owner = Principal.fromBlob(ownerBlob);
                  subaccount = null;
                };
              };
              case (_) {
                {
                  owner = Principal.fromText("2vxsx-fae");
                  subaccount = null;
                };
              };
            };
          };
          case (2) {
            let owner = switch (arr[0]) {
              case (#Blob(ownerBlob)) Principal.fromBlob(ownerBlob);
              case (_) Principal.fromText("2vxsx-fae");
            };
            let subaccount = switch (arr[1]) {
              case (#Blob(subBlob)) ?subBlob;
              case (_) null;
            };
            { owner = owner; subaccount = subaccount };
          };
          case (_) {
            {
              owner = Principal.fromText("2vxsx-fae");
              subaccount = null;
            };
          };
        };
      };
      case (_) {
        {
          owner = Principal.fromText("2vxsx-fae");
          subaccount = null;
        };
      };
    };
  };

  private func extractAmount(txMap: [(Text, Value)]) : Nat {
    switch (getMapValue(txMap, "amt")) {
      case (?#Nat(amount)) amount;
      case (_) 0;
    };
  };

  private func extractOptionalNat(txMap: [(Text, Value)], field: Text) : ?Nat {
    switch (getMapValue(txMap, field)) {
      case (?#Nat(value)) ?value;
      case (_) null;
    };
  };

  private func extractOptionalNat64(txMap: [(Text, Value)], field: Text) : ?Nat64 {
    switch (getMapValue(txMap, field)) {
      case (?#Nat64(value)) ?value;
      case (?#Nat(value)) ?Nat64.fromNat(value);
      case (_) null;
    };
  };

  private func extractMemo(txMap: [(Text, Value)]) : ?Blob {
    switch (getMapValue(txMap, "memo")) {
      case (?#Blob(memo)) ?memo;
      case (_) null;
    };
  };

  private func extractCreatedAtTime(txMap: [(Text, Value)]) : ?Nat64 {
    switch (getMapValue(txMap, "ts")) {
      case (?#Nat64(ts)) ?ts;
      case (?#Nat(ts)) ?Nat64.fromNat(ts);
      case (_) null;
    };
  };

  private func extractFee(txMap: [(Text, Value)], blockMap: [(Text, Value)]) : ?Nat {
    // First check top-level block for fee
    switch (getMapValue(blockMap, "fee")) {
      case (?#Nat(value)) ?value;
      case (_) {
        // Fallback to fee in transaction map
        extractOptionalNat(txMap, "fee");
      };
    };
  };
}