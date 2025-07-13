import Debug "mo:base/Debug";
import Legacy "../src/legacy";

actor {
  // Test data based on the example provided
  public func test_convertMintTransaction() {
    let testBlock : Legacy.Value = #Map([
      ("phash", #Blob("\3d\30\58\5c\39\1b\78\1e\e5\be\e7\a6\f8\14\b2\f5\25\f4\db\4c\cc\70\87\2f\c8\e3\9d\5d\8a\30\02\be")),
      ("ts", #Nat(1_752_342_650_428_785_574)),
      ("tx", #Map([
        ("amt", #Nat(4_314_098_691)),
        ("memo", #Blob("\00\00\00\00\68\72\a0\7a")),
        ("op", #Text("mint")),
        ("to", #Array([
          #Blob("\c6\b6\da\d3\db\d4\c6\b9\c1\e2\e8\e9\ad\71\47\bc\4c\fa\07\24\a2\6b\18\d2\01\89\92\74\02")
        ]))
      ]))
    ]);

    let result = Legacy.convertICRC3ToLegacyTransaction([testBlock]);
    
    Debug.print("Test result length: " # debug_show(result.size()));
    assert result.size() == 1;
    
    let transaction = result[0];
    Debug.print("Transaction kind: " # transaction.kind);
    Debug.print("Transaction timestamp: " # debug_show(transaction.timestamp));
    
    assert transaction.kind == "mint";
    assert transaction.timestamp == 1_752_342_650_428_785_574;
    
    switch (transaction.mint) {
      case (?mint) {
        Debug.print("Mint amount: " # debug_show(mint.amount));
        Debug.print("Mint to owner: " # debug_show(mint.to.owner));
        Debug.print("Mint memo: " # debug_show(mint.memo));
        
        assert mint.amount == 4_314_098_691;
        assert mint.memo == ?"\00\00\00\00\68\72\a0\7a";
        assert mint.created_at_time == null;
      };
      case (null) {
        assert false; // Should never reach here
      };
    };
  };

  public func test_convertTransferTransaction() {
    let testBlock : Legacy.Value = #Map([
      ("btype", #Text("1xfer")),
      ("fee", #Nat(10)),
      ("phash", #Blob("h,,\97\82\ff.\9cx&l\a2e\e7KFVv\d1\89\beJ\c5\c5\ad,h\5c<\ca\ce\be")),
      ("ts", #Nat(1_701_109_006_692_276_133)),
      ("tx", #Map([
        ("amt", #Nat(609_618)),
        ("from", #Array([#Blob("\c6\b6\da\d3\db\d4\c6\b9\c1\e2\e8\e9\ad\71\47\bc\4c\fa\07\24\a2\6b\18\d2\01\89\92\74\02")])),
        ("to", #Array([#Blob("\a6\b6\da\d3\db\d4\c6\b9\c1\e2\e8\e9\ad\71\47\bc\4c\fa\07\24\a2\6b\18\d2\01\89\92\74\03")]))
      ]))
    ]);

    let result = Legacy.convertICRC3ToLegacyTransaction([testBlock]);
    
    assert result.size() == 1;
    let transaction = result[0];
    Debug.print("Transfer transaction kind: " # transaction.kind);
    
    assert transaction.kind == "transfer";
    assert transaction.timestamp == 1_701_109_006_692_276_133;
    
    switch (transaction.transfer) {
      case (?transfer) {
        Debug.print("Transfer amount: " # debug_show(transfer.amount));
        Debug.print("Transfer from owner: " # debug_show(transfer.from.owner));
        Debug.print("Transfer to owner: " # debug_show(transfer.to.owner));
        
        assert transfer.amount == 609_618;
        // Note: We can't easily test the exact principal values due to blob conversion
      };
      case (null) {
        assert false; // Should never reach here
      };
    };
  };

  public func test_opFieldFallback() {
    // Test case where operation type is in tx.op field (not btype)
    let testBlock : Legacy.Value = #Map([
      ("phash", #Blob("test_hash")),
      ("ts", #Nat(1_700_000_000_000_000_000)),
      ("tx", #Map([
        ("amt", #Nat(1000)),
        ("op", #Text("1xfer")), // Operation type in tx.op field
        ("from", #Array([#Blob("from_account")])),
        ("to", #Array([#Blob("to_account")]))
      ]))
      // Note: no btype field at block level
    ]);

    let result = Legacy.convertICRC3ToLegacyTransaction([testBlock]);
    
    Debug.print("=== Testing op field fallback ===");
    assert result.size() == 1;
    
    let transaction = result[0];
    Debug.print("Op field fallback - Transaction kind: " # transaction.kind);
    
    // Should be converted to "transfer" from "1xfer"
    assert transaction.kind == "transfer";
    assert transaction.timestamp == 1_700_000_000_000_000_000;
    
    switch (transaction.transfer) {
      case (?transfer) {
        assert transfer.amount == 1000;
        Debug.print("SUCCESS: Correctly identified transfer from tx.op field");
      };
      case (null) {
        assert false; // Should never reach here
      };
    };
  };

  public func test_btypeFieldFallback() {
    // Test case where operation type is in block-level btype field (no tx.op)
    let testBlock : Legacy.Value = #Map([
      ("btype", #Text("1burn")), // Operation type in block-level btype field
      ("phash", #Blob("test_hash")),
      ("ts", #Nat(1_700_000_000_000_000_000)),
      ("tx", #Map([
        ("amt", #Nat(500)),
        ("from", #Array([#Blob("from_account")]))
        // Note: no op field in tx
      ]))
    ]);

    let result = Legacy.convertICRC3ToLegacyTransaction([testBlock]);
    
    Debug.print("=== Testing btype field fallback ===");
    assert result.size() == 1;
    
    let transaction = result[0];
    Debug.print("Btype field fallback - Transaction kind: " # transaction.kind);
    
    // Should be converted to "burn" from "1burn"
    assert transaction.kind == "burn";
    assert transaction.timestamp == 1_700_000_000_000_000_000;
    
    switch (transaction.burn) {
      case (?burn) {
        assert burn.amount == 500;
        Debug.print("SUCCESS: Correctly identified burn from btype field");
      };
      case (null) {
        assert false; // Should never reach here
      };
    };
  };

  public func runTests() : async () {
    Debug.print("=== Testing Legacy Conversion ===");
    test_convertMintTransaction();
    test_convertTransferTransaction();
    test_opFieldFallback();
    test_btypeFieldFallback();
    Debug.print("=== Tests Complete ===");
  };
}
