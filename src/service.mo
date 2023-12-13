module
{
  public type Value = {
    #Blob : Blob;
    #Text : Text;
    #Nat : Nat; // do we need this or can we just use Int?
    #Int : Int;
    #Array : [Value];
    #Map : [(Text, Value)];
  };
  public type GetArchivesArgs = {
    // The last archive seen by the client.
    // The Ledger will return archives coming
    // after this one if set, otherwise it
    // will return the first archives.
    from : ?Principal;
  };
  public type GetArchivesResult = [{
    // The id of the archive
    canister_id : Principal;

    // The first block in the archive
    start : Nat;

    // The last block in the archive
    end : Nat;
  }];

  public type GetBlocksArgs =[{ start : Nat; length : Nat }];

  public type GetBlocksResult = {
    // Total number of blocks in the
    // block log
    log_length : Nat;

    blocks : [{ id : Nat; block: Value }];

    archived_blocks : [{
        args : GetBlocksArgs;
        callback : query (GetBlocksArgs) -> async (GetBlocksResult);
    }];
};

type DataCertificate =  {
  // See https://internetcomputer.org/docs/current/references/ic-interface-spec#certification
  certificate : Blob;

  // CBOR encoded hash_tree
  hash_tree : Blob;
};


  public type Service = actor {
    icrc3_get_archives : query (GetArchivesArgs) -> async (GetArchivesResult) ;
    icrc3_get_tip_certificate : query () -> async (?DataCertificate);
    icrc3_get_blocks : query (GetBlocksArgs) -> async (GetBlocksResult);
  };
}