import Array "mo:base/Array";
import Blob "mo:base/Blob";
import D "mo:base/Debug";
import Error "mo:base/Error";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import C "mo:matchers/Canister";
import M "mo:matchers/Matchers";
import S "mo:matchers/Suite";
import T "mo:matchers/Testable";
import Text "mo:base/Text";
import Fake "fake";
import RepIndy "mo:rep-indy-hash";

import Example "../example/main";
import ICRC3Types "../src/migrations/types";
import ICRC3 "../src";

shared(init_msg) actor class() = this {

  let baseState = {
    maxActiveRecords = 4;
    settleToRecords = 2;
    maxRecordsInArchiveInstance = 6;
    maxArchivePages  = 62500;
    archiveIndexType = #Stable;
    maxRecordsToArchive = 10_000;
    archiveCycles = 2_000_000_000_000; //two trillion
    archiveControllers = null;
    supportedBlocks : [ICRC3Types.Current.BlockType] = [
      {
        block_type = "test";
        url = "url";
      }
    ]
  };

  public shared func test() : async {
        #success;
        #fail : Text;
    }{
    let suite = S.suite(
      "ICRC3 Canister Tests",
      [
        S.test(
          "testICRC3ArchiveAndRosettaEndpoints",
          switch(await testICRC3ArchiveAndRosettaEndpoints()){case(#success){true};case(_){false};},
          M.equals<Bool>(T.bool(true))
        )
      ]
    );
    S.run(suite);
    return #success;
  };

  public shared func testICRC3ArchiveAndRosettaEndpoints() : async { #success; #fail : Text } {
    ExperimentalCycles.add<system>(10_000_000_000_000);
    let ledger = await Example.Example(baseState);

    // Create 20 transactions
    for (i in Iter.range(1, 20)) {
      let transaction : ICRC3.Transaction =  #Map([
          ("op", #Text("2approve")),
          ("amount", #Nat(400000)),
          ("ts", #Nat(30000)),
          ("from", #Array([#Blob(Principal.toBlob(Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe")))])),
          ("spender", #Array([#Blob(Principal.toBlob(Principal.fromText("agtsn-xyaaa-aaaag-ak3kq-cai")))])),
        ]);
    
      let top : ICRC3.Transaction = #Map([
        ("ts", #Nat(1000)),
        ("btype", #Text("2approve")),
      ]);
      let index = await ledger.add_record2(transaction, ?top);
    };

    // Retrieve blocks and verify they are archived correctly
    let retrievalResult = await ledger.icrc3_get_blocks([{start = 0; length = 20}]);

    let suite = S.suite(
      "testICRC3ArchiveAndRosettaEndpoints",
      [
        
        S.test(
          "Verify the total log length is 20",
          retrievalResult.log_length,
          M.equals<Nat>(T.nat(20))
        )
      ]
    );

   

    S.run(suite);
    return #success;
  };
};
