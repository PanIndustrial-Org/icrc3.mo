# icrc3.mo

## Install
```
mops add icrc3-mo
```

## Usage
```motoko
import ICRC3 "mo:icrc3.mo";
```

## Initialization

To properly instantiate the ICRC3 component, follow the example below. This implementation uses the `ClassPlus` pattern for managing stable memory and migrations.

### Example Initialization

```motoko
import ICRC3 "mo:icrc3.mo";
import Principal "mo:base/Principal";
import CertTree "mo:cert/CertTree";
import ClassPlus "mo:class-plus";

shared(init_msg) actor class Example(_args: ?ICRC3.InitArgs) = this {

  stable let cert_store : CertTree.Store = CertTree.newStore();
  let ct = CertTree.Ops(cert_store);

  let manager = ClassPlus.ClassPlusInitializationManager(init_msg.caller, Principal.fromActor(this), true);

  private func get_icrc3_environment() : ICRC3.Environment {
    {
      updated_certification = ?updated_certification;
      get_certificate_store = ?get_certificate_store;
    };
  };

  private func get_certificate_store() : CertTree.Store {
    return cert_store;
  };

  private func updated_certification(cert: Blob, lastIndex: Nat) : Bool {
    ct.setCertifiedData();
    return true;
  };

  stable var icrc3_migration_state = ICRC3.initialState();

  let icrc3 = ICRC3.Init<system>({
    manager = manager;
    initialState = icrc3_migration_state;
    args = _args;
    pullEnvironment = ?get_icrc3_environment;
    onInitialize = ?(func(newClass: ICRC3.ICRC3) : async*() {
      if (newClass.stats().supportedBlocks.size() == 0) {
        newClass.update_supported_blocks([
          { block_type = "uupdate_user"; url = "https://git.com/user" },
          { block_type = "uupdate_role"; url = "https://git.com/user" },
          { block_type = "uupdate_use_role"; url = "https://git.com/user" }
        ]);
      };
    });
    onStorageChange = func(state: ICRC3.State) {
      icrc3_migration_state := state;
    };
  });

  public query func icrc3_get_blocks(args: ICRC3.GetBlocksArgs) : async ICRC3.GetBlocksResult {
    return icrc3().get_blocks(args);
  };

  public query func icrc3_get_archives(args: ICRC3.GetArchivesArgs) : async ICRC3.GetArchivesResult {
    return icrc3().get_archives(args);
  };

  public query func icrc3_supported_block_types() : async [ICRC3.BlockType] {
    return icrc3().supported_block_types();
  };

  public query func icrc3_get_tip_certificate() : async ?ICRC3.DataCertificate {
    return icrc3().get_tip_certificate();
  };

  public query func get_tip() : async ICRC3.Tip {
    return icrc3().get_tip();
  };
};
```

### InitArgs

The `InitArgs` type defines the configuration for the ICRC3 component:

```motoko
public type InitArgs = {
  maxActiveRecords : Nat; // Allowed max active records on this canister
  settleToRecords : Nat; // Number of records to settle to during the clean-up process
  maxRecordsInArchiveInstance : Nat; // Max number of archive items per archive instance
  maxArchivePages : Nat; // Max number of pages allowed on the archive server
  archiveIndexType : SW.IndexType; // Index type for archive memory
  maxRecordsToArchive : Nat; // Max number of records to archive in one round
  archiveCycles : Nat; // Number of cycles to send to a new archive canister
  archiveControllers : ?[Principal]; // Override default controllers; the canister adds itself to this group
};
```

## Maintenance and Archival

Each time a transaction is added, the ledger checks to see if it has exceeded its max length. If it has, it sets a timer to run in the next round to run the archive.  It will only attempt to archive a chunk at a time as configured and will set it self to run again if it was unable to reach its settled records.

When the first archive reaches its limit, the class will create a new archive canister and send it the number of configured cycles. It will fail silently if there are not enough cycles.

## Transaction Log Best Practices

This class supports an ICRC3 style, write only transaction log. It supports archiving to other canisters on the same subnet.  Multi subnet archiving and archive splitting is not yet supported, but is planned for future versions.

Typically you want to keep a small number of transactions on your main canister with frequent and often archival of transactions to the archive. For example, the ICP ledger uses 2000 transactions as the max and 1000 as the settle to. If you utilize stable memory, you should be able to write a very large number of transactions to your archive.  We do not yet have benchmarks and have yet to do max out testing, but we feel comfortable saying that 4GB or 62500 pages should be safe.  You will need to determine for your self what the max number of records that can fit into the alloted pages is.  If you have a variable or unbounded transaction type you may need to consider putting your max pages higher and number of transactions lower.

Future versions may make this more dynamic.

Future Todos:

- Archive Upgrades
- Multi-subnet archives
- Archive Splitting
- Automatic memory monitoring

