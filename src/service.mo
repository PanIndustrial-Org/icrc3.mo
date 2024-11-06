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
  public type GetRosettaBlocksArgs ={ start : Nat; length : Nat };

  public type Block = { id : Nat; block: Value };

  public type ArchivedBlock = {
        args : GetBlocksArgs;
        callback : query (GetBlocksArgs) -> async (GetBlocksResult);
    };

  public type GetBlocksResult = {
    // Total number of blocks in the
    // block log
    log_length : Nat;

    blocks : [Block];

    archived_blocks : [ArchivedBlock];
  };

  public type GetRosettaBlocksResults = {
    first_index : Nat;
    log_length : Nat;
    transactions : [RosettaTransaction];
    archived_transactions : [RosettaArchivedRange];
  };

  public type RosettaArchivedRange = {
    callback : shared query GetRosettaBlocksRequest -> async RosettaArchivedResult;
    start : Nat;
    length : Nat;
  };

   public type RosettaArchivedResult = {
    transactions: [RosettaTransaction];
  };

  public type RosettaTransactionRange = { transactions : [RosettaTransaction] };

  public type GetRosettaBlocksRequest = { start : Nat; length : Nat };

  public type Account = { owner : Principal; subaccount : ?Blob };

  public type RosettaTransaction = {
    burn : ?RosettaBurn;
    kind : Text;
    mint : ?RosettaMint;
    approve : ?RosettaApprove;
    timestamp : Nat64;
    transfer : ?RosettaTransfer;
  };

  public type RosettaApprove = {
    fee : ?Nat;
    from : Account;
    memo : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
    expected_allowance : ?Nat;
    expires_at : ?Nat64;
    spender : Account;
  };

  public type RosettaBurn = {
    from : Account;
    memo : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
    spender : ?Account;
  };

  public type RosettaMint = {
    to : Account;
    memo : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
  };

  public type RosettaTransfer = {
    to : Account;
    fee : ?Nat;
    from : Account;
    memo : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
    spender : ?Account;
  };
 
  public type DataCertificate =  {
    // See https://internetcomputer.org/docs/current/references/ic-interface-spec#certification
    certificate : Blob;

    // CBOR encoded hash_tree
    hash_tree : Blob;
  };

  public type BlockType = {
    block_type : Text;
    url : Text;
  };

  public type GetRosettaArchiveTransactionsFn = shared query (GetRosettaBlocksRequest) -> async RosettaArchivedResult;


  public type Service = actor {
    icrc3_get_archives : query (GetArchivesArgs) -> async (GetArchivesResult) ;
    icrc3_get_tip_certificate : query () -> async (?DataCertificate);
    icrc3_get_blocks : query (GetBlocksArgs) -> async (GetBlocksResult);
    icrc3_supported_block_types: query () -> async [BlockType];
    get_transactions : query (GetRosettaBlocksArgs) -> async GetRosettaBlocksResults;
  };

    public type ArchiveService = actor {
    icrc3_get_archives : query (GetArchivesArgs) -> async (GetArchivesResult) ;
    icrc3_get_tip_certificate : query () -> async (?DataCertificate);
    icrc3_get_blocks : query (GetBlocksArgs) -> async (GetBlocksResult);
    icrc3_supported_block_types: query () -> async [BlockType];
    get_transactions : query (GetRosettaBlocksRequest) -> async RosettaArchivedResult;
    get_tip_certificate : query () -> async DataCertificate;
  };
}