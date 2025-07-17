///////////////////////////////////////////////////////////////////////////////////////////
/// Base Library for ICRC-3 Standards
///
/// This library includes the necessary functions, types, and classes to build an ICRC-3 standard transactionlog. It provides an implementation of the
/// ICRC3 class which manages the transaction ledger, archives, and certificate store.
///
///
///////////////////////////////////////////////////////////////////////////////////////////

import MigrationTypes "./migrations/types";
import Migration "./migrations";
import Archive "/archive/";

import Blob "mo:base/Blob";
import D "mo:base/Debug";
import CertifiedData "mo:base/CertifiedData";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Vec "mo:vector";
import Map "mo:map/Map";
import Set "mo:map/Set";
import RepIndy "mo:rep-indy-hash";
import HelperLib "helper";

import MTree "mo:ic-certification/MerkleTree";
import Service "service";
import ClassPlusLib "mo:class-plus";
import LegacyLib "legacy";

module {

  /// Debug channel configuration
  ///
  /// The debug_channel object is used to enable/disable different debugging
  /// messages during runtime.
  let debug_channel = {
    add_record = false;
    certificate = false;
    clean_up = false;
    get_transactions = false;
  };

  /// Represents the current state of the migration
  public type CurrentState = MigrationTypes.Current.State;
  public type InitArgs = MigrationTypes.Args;



  /// Represents a transaction
  public type Transaction = MigrationTypes.Current.Transaction;
  public type BlockType = MigrationTypes.Current.BlockType;
  public type Value = MigrationTypes.Current.Value;
  public type State = MigrationTypes.State;
  public type Stats = MigrationTypes.Current.Stats;
  public type Environment = MigrationTypes.Current.Environment;
  public type TransactionRange = MigrationTypes.Current.TransactionRange;
  public type GetTransactionsResult = MigrationTypes.Current.GetTransactionsResult;
  public type DataCertificate = MigrationTypes.Current.DataCertificate;
  public type Tip = MigrationTypes.Current.Tip;
  public type GetArchivesArgs = MigrationTypes.Current.GetArchivesArgs;
  public type GetArchivesResult = MigrationTypes.Current.GetArchivesResult;
  public type GetArchivesResultItem = MigrationTypes.Current.GetArchivesResultItem;

  public type GetBlocksArgs = MigrationTypes.Current.GetBlocksArgs;
  public type GetBlocksResult = MigrationTypes.Current.GetBlocksResult;

  public type UpdateSetting = MigrationTypes.Current.UpdateSetting;

  /// Represents the IC actor
  public type IC = MigrationTypes.Current.IC;

  public let CertTree = MigrationTypes.Current.CertTree;




  /// Initializes the initial state
  ///
  /// Returns the initial state of the migration.
  public func initialState() : State {#v0_0_0(#data)};

  /// Returns the current state version
  public let currentStateVersion = #v0_1_0(#id);

  /// Initializes the migration
  ///
  /// This function is used to initialize the migration with the provided stored state.
  ///
  /// Arguments:
  /// - `stored`: The stored state of the migration (nullable)
  /// - `canister`: The canister ID of the migration
  /// - `environment`: The environment object containing optional callbacks and functions
  ///
  /// Returns:
  /// - The current state of the migration
  public let init = Migration.migrate;

  /// Helper library for common functions
  public let helper = HelperLib;
  public let Legacy = LegacyLib;
  public type Service = Service.Service;

  public func Init<system>(config : {
    manager: ClassPlusLib.ClassPlusInitializationManager;
    initialState: State;
    args : ?InitArgs;
    pullEnvironment : ?(() -> Environment);
    onInitialize: ?(ICRC3 -> async*());
    onStorageChange : ((State) ->())
  }) :()-> ICRC3{
    
    //D.print("Subscriber Init");
    switch(config.pullEnvironment){
      case(?val) {
        //D.print("pull environment has value");
        
      };
      case(null) {
        D.print("pull environment is null");
      };
    };  
    ClassPlusLib.ClassPlus<system,
      ICRC3, 
      State,
      InitArgs,
      Environment>({config with constructor = ICRC3}).get;
  };


  /// The ICRC3 class manages the transaction ledger, archives, and certificate store.
  ///
  /// The ICRC3 class provides functions for adding a record to the ledger, getting
  /// archives, getting the certificate, and more.
  public class ICRC3(stored: ?State, caller: Principal, canister: Principal, args: ?InitArgs, environment_passed: ?Environment, storageChanged: (State) -> ()){

    public let environment = switch(environment_passed){
      case(null) D.trap("No Environment Provided");
      case(?val) val;
    };


    /// The current state of the migration
    var state : CurrentState = switch(stored){
      case(null) {
        let #v0_1_0(#data(foundState)) = init(initialState(), currentStateVersion, args, caller, canister);
        foundState;
      };
      case(?val) {
        let #v0_1_0(#data(foundState)) = init(val, currentStateVersion, args, caller, canister);
        foundState;
      };
    };

    storageChanged(#v0_1_0(#data(state)));

    /// The migrate function
    public let migrate = Migration.migrate;

    /// The IC actor used for updating archive controllers
    private let ic : IC = actor "aaaaa-aa";

    /// Encodes a number as big-endian bytes
    ///
    /// Arguments:
    /// - `nat`: The number to encode
    ///
    /// Returns:
    /// - The encoded bytes
    func encodeBigEndian(nat: Nat): Blob {
      var tempNat = nat;
      var bitCount = 0;
      while (tempNat > 0) {
        bitCount += 1;
        tempNat /= 2;
      };
      let byteCount = (bitCount + 7) / 8;

      var buffer = Vec.init<Nat8>(byteCount, 0);
      for (i in Iter.range(0, byteCount-1)) {
        let byteValue = Nat.div(nat, Nat.pow(256, i)) % 256;
        Vec.put(buffer, i, Nat8.fromNat(byteValue));
      };

      Vec.reverse<Nat8>(buffer);
      return Blob.fromArray(Vec.toArray<Nat8>(buffer));
    };

    /// Adds a record to the transaction ledger
    ///
    /// This function adds a new record to the transaction ledger.
    ///
    /// Arguments:
    /// - `new_record`: The new record to add
    /// - `top_level`: The top level value (nullable)
    ///
    /// Returns:
    /// - The index of the new record
    ///
    /// Throws:
    /// - An error if the `op` field is missing from the transaction
    public func add_record<system>(new_record: Transaction, top_level: ?Value) : Nat {

      //validate that the trx has an op field according to ICRC3
      //let ?type_id = helper.get_item_from_map("op", top_level) else D.trap("missing the op field");

      debug if(debug_channel.add_record) D.print("adding a record" # debug_show(new_record));

      let current_size = Vec.size(state.ledger);

      debug if(debug_channel.add_record) D.print("current_size" # debug_show(current_size));
      

      let last_rec : ?Transaction = if(current_size == 0){
        null;
      } else {
        ?Vec.get<Transaction>(state.ledger, current_size - 1);
      };

      debug if(debug_channel.add_record) D.print("last_rec" # debug_show(last_rec));

      let trx = Vec.new<(Text, Transaction)>();

      //add a phash in accordance with ICRC3 for records > idx 0
      switch(state.latest_hash){
        case(null) {};
        case(?val){
          Vec.add(trx, ("phash", #Blob(val)));
        };
      };

      Vec.add(trx,("tx", new_record));

      switch(top_level){
        case(?top_level){
          switch(top_level){
            case(#Map(items)){
              for(thisItem in items.vals()){
                Vec.add(trx,(thisItem.0, thisItem.1));
              };
            };
            case(_){};
          }
        };
        case(null){};
      };

      debug if(debug_channel.add_record) D.print("full tx" # debug_show(Vec.toArray(trx)));

      let thisTrx = #Map(Vec.toArray(trx));

      //calculate and set the certifiable hash of the tip of the ledger
      state.latest_hash := ?Blob.fromArray(RepIndy.hash_val(thisTrx));

      Vec.add(state.ledger, thisTrx);

      if(state.lastIndex == 0) {
        state.lastIndex :=  Vec.size(state.ledger) - 1;
      } else state.lastIndex += 1;

      //set a timer to clean up
      if(Vec.size(state.ledger) > state.constants.archiveProperties.maxActiveRecords){
        switch(state.cleaningTimer){
          case(null){ //only need one active timer
            debug if(debug_channel.add_record) D.print("setting clean up timer");
            state.cleaningTimer := ?Timer.setTimer<system>(#seconds(0), check_clean_up);
          };
          case(_){}
        };
      };

      debug if(debug_channel.add_record) D.print("about to certify " # debug_show(state.latest_hash));

      //certify the new record if the cert store is provided


            switch(environment.get_certificate_store, state.latest_hash){
        
        case(?gcs, ?latest_hash){
          debug if(debug_channel.add_record) D.print("have store" # debug_show(gcs()));
          let ct = CertTree.Ops(gcs());
          ct.put([Text.encodeUtf8("last_block_index")], encodeBigEndian(state.lastIndex));
          ct.put([Text.encodeUtf8("last_block_hash")], latest_hash);
          ct.setCertifiedData();
        };
        case(_){};
      };
      
      switch(environment.updated_certification, state.latest_hash){
        
        case(?uc, ?latest_hash){
          debug if(debug_channel.add_record) D.print("have cert update");
          ignore uc(latest_hash, state.lastIndex);
        };
        case(_){};
      };

 

      return state.lastIndex;
    };

    /// Returns the archive index for the ledger
    ///
    /// This function returns the archive index for the ledger.
    ///
    /// Arguments:
    /// - `request`: The archive request
    ///
    /// Returns:
    /// - The archive index
    public func get_archives(request: Service.GetArchivesArgs) : Service.GetArchivesResult {
      let results = Vec.new<GetArchivesResultItem>();
       
      var bFound = switch(request.from){
        case(null) true;
        case(?val) false;
      };
      if(bFound == true){
          Vec.add(results,{
            canister_id = canister;
            start = state.firstIndex;
            end = state.lastIndex;
          });
        } else {
          switch(request.from){
            case(null) {}; //unreachable
            case(?val) {
              if(canister == val){
                bFound := true;
              };
            };
          };
        };

      for(thisItem in Map.entries<Principal, TransactionRange>(state.archives)){
        if(bFound == true){
          if(thisItem.1.start + thisItem.1.length >= 1){
            Vec.add(results,{
              canister_id = thisItem.0;
              start = thisItem.1.start;
              end = Nat.sub(thisItem.1.start + thisItem.1.length, 1);
            });
          } else{
            D.trap("found archive with length of 0");
          };
        } else {
          switch(request.from){
            case(null) {}; //unreachable
            case(?val) {
              if(thisItem.0 == val){
                bFound := true;
              };
            };
          };
        };
      };

      return Vec.toArray(results);
    };

    /// Returns the certificate for the ledger
    ///
    /// This function returns the certificate for the ledger.
    ///
    /// Returns:
    /// - The data certificate (nullable)
    public func get_tip_certificate() : ?Service.DataCertificate{
      debug if(debug_channel.certificate) D.print("in get tip certificate");
     
      debug if(debug_channel.certificate) D.print("have env");
      switch(environment.get_certificate_store){
        case(null){};
        case(?gcs){
          debug if(debug_channel.certificate) D.print("have gcs");
          let ct = CertTree.Ops(gcs());
          let blockWitness = ct.reveal([Text.encodeUtf8("last_block_index")]);
          let hashWitness = ct.reveal([Text.encodeUtf8("last_block_hash")]);
          let merge = MTree.merge(blockWitness,hashWitness);
          let witness = ct.encodeWitness(merge);
          return ?{
            certificate = switch(CertifiedData.getCertificate()){
              case(null){
                debug if(debug_channel.certificate) D.print("certified returned null");
                return null;
              };

              case(?val) val;
            };
            hash_tree = witness;
          };
        };
      };


      return null;
    };

    /// Returns the latest hash and lastest index along with a witness
    ///
    /// This function returns the latest hash, latest index, and the witness for the ledger.
    ///
    /// Returns:
    /// - The tip information
    public func get_tip() : Tip {
      debug if(debug_channel.certificate) D.print("in get tip certificate");
            debug if(debug_channel.certificate) D.print("have env");
      switch(environment.get_certificate_store){
        case(null){D.trap("No certificate store provided")};
        case(?gcs){
          debug if(debug_channel.certificate) D.print("have gcs");
          let ct = CertTree.Ops(gcs());
          let blockWitness = ct.reveal([Text.encodeUtf8("last_block_index")]);
          let hashWitness = ct.reveal([Text.encodeUtf8("last_block_hash")]);
          let merge = MTree.merge(blockWitness,hashWitness);
          let witness = ct.encodeWitness(merge);
          return {
            last_block_hash = switch(state.latest_hash){
              case(null) D.trap("No root");
              case(?val) val;
            };
            last_block_index = encodeBigEndian(state.lastIndex);
            hash_tree = witness;

          };
        };
      };
    };


    /// Updates the controllers for the given canister
    ///
    /// This function updates the controllers for the given canister.
    ///
    /// Arguments:
    /// - `canisterId`: The canister ID
    private func update_controllers(canisterId : Principal) : async (){
      switch(state.constants.archiveProperties.archiveControllers){
        case(?val){
          let final_list = switch(val){
            case(?list){
              let a_set = Set.fromIter<Principal>(list.vals(), Map.phash);
              Set.add(a_set, Map.phash, canister);
              ?Set.toArray(a_set);
            };
            case(null){
              ?[canister];
            };
          };
          ignore ic.update_settings(({canister_id = canisterId; settings = {
                    controllers = final_list;
                    freezing_threshold = null;
                    memory_allocation = null;
                    compute_allocation = null;
          }}));
        };
        case(_){};    
      };

      return;
    };

    /// Updates the controllers for the given canister
    ///
    /// This function updates the controllers for the given canister.
    ///
    /// Arguments:
    /// - `canisterId`: The canister ID
    public func update_supported_blocks(supported_blocks : [BlockType]) : () {
      Vec.clear(state.supportedBlocks);
      Vec.addFromIter(state.supportedBlocks, supported_blocks.vals());
      return;
    };

 
    public func update_settings(settings : [UpdateSetting]) : [Bool]{

    let results = Vec.new<Bool>();
     for(setting in settings.vals()){
          Vec.add(results, switch(setting) {
            case(#maxActiveRecords(maxActiveRecords)){
              state.constants.archiveProperties.maxActiveRecords := maxActiveRecords;
              true;
            };
            case(#settleToRecords(settleToRecords)){
              state.constants.archiveProperties.settleToRecords := settleToRecords;
              true;
            };
            case(#maxRecordsInArchiveInstance(maxRecordsInArchiveInstance)){
              state.constants.archiveProperties.maxRecordsInArchiveInstance := maxRecordsInArchiveInstance;
              true;
            };
            case(#maxRecordsToArchive(maxRecordsToArchive)){
              state.constants.archiveProperties.maxRecordsToArchive := maxRecordsToArchive;
              true;
            };
            case(#maxArchivePages(maxArchivePages)){
              state.constants.archiveProperties.maxArchivePages := maxArchivePages;
              true;
            };
            case(#archiveIndexType(archiveIndexType)){
              state.constants.archiveProperties.archiveIndexType := archiveIndexType;
              true;
            };
            case(#archiveCycles(archiveCycles)){
              state.constants.archiveProperties.archiveCycles := archiveCycles;
              true;
            };
            case(#archiveControllers(archiveControllers)){
              state.constants.archiveProperties.archiveControllers := archiveControllers;
              true;
            };
          });
        };
      return Vec.toArray(results);
    };



    /// Runs the clean up process to move records to archive canisters
    ///
    /// This function runs the clean up process to move records to archive canisters.
    public func check_clean_up<system>() : async (){

      //clear the timer
      state.cleaningTimer := null;

      debug if(debug_channel.clean_up) D.print("Checking clean up" # debug_show(stats()));

      //ensure only one cleaning job is running
      if(state.bCleaning) return; //only one cleaning at a time;
      debug if(debug_channel.clean_up) D.print("Not currently Cleaning");

      //don't clean if not necessary
      if(Vec.size(state.ledger) < state.constants.archiveProperties.maxActiveRecords) return;

      state.bCleaning := true;

      debug if(debug_channel.clean_up) D.print("Now we are cleaning");

      let (archive_detail, available_capacity) = if(Map.size(state.archives) == 0){
        //no archive exists - create a new canister
        //add cycles;
        debug if(debug_channel.clean_up) D.print("Creating a canister");

        if(ExperimentalCycles.balance() > state.constants.archiveProperties.archiveCycles * 2){
          ExperimentalCycles.add<system>(state.constants.archiveProperties.archiveCycles);
        } else{
          //warning ledger will eventually overload
          debug if(debug_channel.clean_up) D.print("Not enough cycles" # debug_show(ExperimentalCycles.balance() ));
            state.bCleaning :=false;
          return;
        };

        //commits state and creates archive
        let newArchive = await Archive.Archive({
          maxRecords = state.constants.archiveProperties.maxRecordsInArchiveInstance;
          indexType = #Stable;
          maxPages = state.constants.archiveProperties.maxArchivePages;
          firstIndex = 0;
        });
        //set archive controllers calls async
        ignore update_controllers(Principal.fromActor(newArchive));

        let newItem = {
          start = 0;
          length = 0;
        };

        debug if(debug_channel.clean_up) D.print("Have an archive");

        ignore Map.put<Principal, TransactionRange>(state.archives, Map.phash, Principal.fromActor(newArchive),newItem);

        ((Principal.fromActor(newArchive), newItem), state.constants.archiveProperties.maxRecordsInArchiveInstance);
      } else{
        //check that the last one isn't full;
        debug if(debug_channel.clean_up) D.print("Checking old archive");
        let lastArchive = switch(Map.peek(state.archives)){
          case(null) {D.trap("unreachable")}; //unreachable;
          case(?val) val;
        };
        
        if(lastArchive.1.length >= state.constants.archiveProperties.maxRecordsInArchiveInstance){
          //this one is full, create a new archive
          debug if(debug_channel.clean_up) D.print("Need a new canister");
          if(ExperimentalCycles.balance() > state.constants.archiveProperties.archiveCycles * 2){
            ExperimentalCycles.add<system>(state.constants.archiveProperties.archiveCycles);
          } else{
            //warning ledger will eventually overload
            state.bCleaning :=false;
            return;
          };

          let newArchive = await Archive.Archive({
            maxRecords = state.constants.archiveProperties.maxRecordsInArchiveInstance;
            indexType = #Stable;
            maxPages = state.constants.archiveProperties.maxArchivePages;
            firstIndex = lastArchive.1.start + lastArchive.1.length;
          });

          debug if(debug_channel.clean_up) D.print("Have a multi archive");
          let newItem = {
            start = state.firstIndex;
            length = 0;
          };
          ignore Map.put(state.archives, Map.phash, Principal.fromActor(newArchive), newItem);
          ((Principal.fromActor(newArchive), newItem), state.constants.archiveProperties.maxRecordsInArchiveInstance);
        } else {
          debug if(debug_channel.clean_up) D.print("just giving stats");
          
          let capacity = if(state.constants.archiveProperties.maxRecordsInArchiveInstance >= lastArchive.1.length){
            Nat.sub(state.constants.archiveProperties.maxRecordsInArchiveInstance,  lastArchive.1.length);
          } else {
            D.trap("max archive lenghth must be larger than the last archive length");
          };

          (lastArchive, capacity);
        };
      };

      let archive = actor(Principal.toText(archive_detail.0)) : MigrationTypes.Current.ArchiveInterface;

      var archive_amount = if(Vec.size(state.ledger) > state.constants.archiveProperties.settleToRecords){
        Nat.sub(Vec.size(state.ledger), state.constants.archiveProperties.settleToRecords)
      } else {
        D.trap("Settle to records must be equal or smaller than the size of the ledger upon clanup");
      };

      debug if(debug_channel.clean_up) D.print("amount to archive is " # debug_show(archive_amount));

      var bRecallAtEnd = false;

      if(archive_amount > available_capacity){
        bRecallAtEnd := true;
        archive_amount := available_capacity;
      };

      if(archive_amount > state.constants.archiveProperties.maxRecordsToArchive){
        bRecallAtEnd := true;
        archive_amount := state.constants.archiveProperties.maxRecordsToArchive;
      };

      debug if(debug_channel.clean_up) D.print("amount to archive updated to " # debug_show(archive_amount));

      let toArchive = Vec.new<Transaction>();
      label find for(thisItem in Vec.vals(state.ledger)){
        Vec.add(toArchive, thisItem);
        if(Vec.size(toArchive) == archive_amount) break find;
      };

      debug if(debug_channel.clean_up) D.print("tArchive size " # debug_show(Vec.size(toArchive)));

      try{
        let result = await archive.append_transactions(Vec.toArray(toArchive));
        let stats = switch(result){
          case(#ok(stats)) stats;
          case(#Full(stats)) stats;
          case(#err(_)){
            //do nothing...it failed;
            state.bCleaning :=false;
            return;
          };
        };

        let new_ledger = Vec.new<Transaction>();
        var tracker = 0;
        let archivedAmount = Vec.size(toArchive);
        for(thisItem in Vec.vals(state.ledger)){
          if(tracker >= archivedAmount){
            Vec.add(new_ledger, thisItem)
          };
          tracker += 1;
        };
        state.firstIndex := state.firstIndex + archivedAmount;
        state.ledger := new_ledger;
        debug if(debug_channel.clean_up) D.print("new ledger size " # debug_show(Vec.size(state.ledger)));
        ignore Map.put(state.archives, Map.phash, Principal.fromActor(archive),{
          start = archive_detail.1.start;
          length = archive_detail.1.length + archivedAmount;
        })
      } catch (_){
        //what do we do when it fails?  keep them in memory?
        state.bCleaning :=false;
        return;
      };

      state.bCleaning :=false;

      if(bRecallAtEnd){
        state.cleaningTimer := ?Timer.setTimer<system>(#seconds(0), check_clean_up);
      };

      debug if(debug_channel.clean_up) D.print("Checking clean up" # debug_show(stats()));
      return;
    };

    type TransactionTypes = {
      id: Nat;
      transaction: Transaction;
    };

    /// Returns the statistics of the migration
    ///
    /// This function returns the statistics of the migration.
    ///
    /// Returns:
    /// - The migration statistics
    public func stats() : Stats {
      return {
        localLedgerSize = Vec.size(state.ledger);
        lastIndex = state.lastIndex;
        firstIndex = state.firstIndex;
        archives = Iter.toArray(Map.entries<Principal, TransactionRange>(state.archives));
        ledgerCanister = canister;
        supportedBlocks = Iter.toArray<BlockType>(Vec.vals(state.supportedBlocks));
        bCleaning = state.bCleaning;
        constants = {
          archiveProperties = {
            maxActiveRecords = state.constants.archiveProperties.maxActiveRecords;
            settleToRecords = state.constants.archiveProperties.settleToRecords;
            maxRecordsInArchiveInstance = state.constants.archiveProperties.maxRecordsInArchiveInstance;
            maxRecordsToArchive = state.constants.archiveProperties.maxRecordsToArchive;
            archiveCycles = state.constants.archiveProperties.archiveCycles;
            archiveControllers = state.constants.archiveProperties.archiveControllers;
          };
        };
      };
    };

    /// Returns the statistics of the migration
    ///
    /// This function returns the statistics of the migration.
    ///
    /// Returns:
    /// - The migration statistics
    public func get_state() : CurrentState {
      return state;
    };

    ///Returns an array of supported block types.
    ///
    /// @returns {Array<BlockType>} The array of supported block types.
    public func supported_block_types() : [BlockType] {
      return Vec.toArray(state.supportedBlocks);
    };

    /// Returns a set of transactions and pointers to archives if necessary
    /// Core function that extracts the shared logic for both get_blocks and get_blocks_legacy
    ///
    /// Returns raw blocks and archive information that can be formatted differently
    private func get_blocks_core(args: [{start: Nat; length: Nat}]) : {
      ledger_length: Nat;
      blocks: Vec.Vector<{id: Nat; block: Value}>;
      archives: Map.Map<Principal, Vec.Vector<TransactionRange>>;
      first_index: ?Nat;
    } {

      debug if(debug_channel.get_transactions) D.print("Vec.size(state.ledger)" # debug_show((Vec.size(state.ledger), Vec.toArray(state.ledger))));
      let local_ledger_length = Vec.size(state.ledger);

      var first_index : ?Nat = null;


      let ledger_length = if(state.lastIndex == 0 and local_ledger_length == 0) {
        0;
      } else {
        state.lastIndex + 1;
      };

      debug if(debug_channel.get_transactions) D.print("have ledger length" # debug_show(ledger_length));

      //get the transactions on this canister
      let transactions = Vec.new<{id: Nat; block: Value}>();
      label proc for(thisArg in args.vals()){
        debug if(debug_channel.get_transactions) D.print("setting start " # debug_show(thisArg.start + thisArg.length, state.firstIndex));
        
        // Skip if length is 0 - no blocks to retrieve
        if(thisArg.length == 0) {
          continue proc;
        };
        
        if(thisArg.start + thisArg.length > state.firstIndex){
          debug if(debug_channel.get_transactions) D.print("setting start " # debug_show(thisArg.start + thisArg.length, state.firstIndex));
          let start = if(thisArg.start <= state.firstIndex){
            debug if(debug_channel.get_transactions) D.print("setting start " # debug_show(0));
            0;
          } else{
            debug if(debug_channel.get_transactions) D.print("getting trx" # debug_show(state.lastIndex, state.firstIndex, thisArg));
            if(thisArg.start >= (state.firstIndex)){
              Nat.sub(thisArg.start, (state.firstIndex));
            } else {
              D.trap("last index must be larger than requested start plus one");
            };
          };

          let end = if(Vec.size(state.ledger)==0){
            0;
          } else if(thisArg.start + thisArg.length > state.lastIndex + 1){
            Nat.sub(Vec.size(state.ledger), 1);
          } else {
            // Calculate the actual end index (exclusive), then make it inclusive for Iter.range
            let localEndIndex = Nat.sub(thisArg.start + thisArg.length, state.firstIndex);
            if(localEndIndex > 0 and localEndIndex <= Vec.size(state.ledger)) {
              Nat.sub(localEndIndex, 1);
            } else {
              0;
            };
          };


          debug if(debug_channel.get_transactions) D.print("getting local transactions" # debug_show(start,end));
          //some of the items are on this server
          if(Vec.size(state.ledger) > 0 and start <= end){
            label search for(thisItem in Iter.range(start, end)){
              debug if(debug_channel.get_transactions) D.print("testing" # debug_show(thisItem));
              if(thisItem >= Vec.size(state.ledger)){
                break search;
              };
              if(first_index == null){
                debug if(debug_channel.get_transactions) D.print("setting first index" # debug_show(state.firstIndex + thisItem));
                first_index := ?(state.firstIndex + thisItem);
              };
              Vec.add(transactions, {
                  id = state.firstIndex + thisItem;
                  block = Vec.get(state.ledger, thisItem)
              });
            };
          };
        };
      };

      //get any relevant archives
      let archives = Map.new<Principal, Vec.Vector<TransactionRange>>();

      for(thisArgs in args.vals()){
        if(thisArgs.start < state.firstIndex){
          
          debug if(debug_channel.get_transactions) D.print("archive settings are " # debug_show(Iter.toArray(Map.entries(state.archives))));
          var seeking = thisArgs.start;
          label archive for(thisItem in Map.entries(state.archives)){
            if (seeking > Nat.sub(thisItem.1.start + thisItem.1.length, 1) or thisArgs.start + thisArgs.length <= thisItem.1.start) {
                continue archive;
            };

            // Calculate the start and end indices of the intersection between the requested range and the current archive.
            let overlapStart = Nat.max(seeking, thisItem.1.start);
            let overlapEnd = Nat.min(thisArgs.start + thisArgs.length - 1, thisItem.1.start + thisItem.1.length - 1);
            let overlapLength = Nat.sub(overlapEnd, overlapStart) + 1;

            // Create an archive request for the overlapping range.
            switch(Map.get(archives, Map.phash, thisItem.0)){
              case(null){
                let newVec = Vec.new<TransactionRange>();
                Vec.add(newVec, {
                    start = overlapStart;
                    length = overlapLength;
                  });
                ignore Map.put<Principal, Vec.Vector<TransactionRange>>(archives, Map.phash, thisItem.0, newVec);
              };
              case(?existing){
                Vec.add(existing, {
                  start = overlapStart;
                  length = overlapLength;
                });
              };
            };

            // If the overlap ends exactly where the requested range ends, break out of the loop.
            if (overlapEnd == Nat.sub(thisArgs.start + thisArgs.length, 1)) {
                break archive;
            };

            // Update seeking to the next desired transaction.
            seeking := overlapEnd + 1;
          };
        };
      };

      debug if(debug_channel.get_transactions) D.print("returning transactions result" # debug_show(ledger_length, Vec.size(transactions), Map.size(archives)));
      
      return {
        ledger_length = ledger_length;
        blocks = transactions;
        archives = archives;
        first_index = first_index;
      };
    };

    ///
    /// This function returns a set of transactions and pointers to archives if necessary.
    ///
    /// Arguments:
    /// - `args`: The transaction range
    ///
    /// Returns:
    /// - The result of getting transactions
    public func get_blocks(args: Service.GetBlocksArgs) : Service.GetBlocksResult {
      let coreResult = get_blocks_core(args);
      
      //build the result
      return {
        log_length = coreResult.ledger_length;
        blocks = Vec.toArray(coreResult.blocks);
        archived_blocks = Iter.toArray<Service.ArchivedBlock>(Iter.map<(Principal, Vec.Vector<TransactionRange>), Service.ArchivedBlock>(Map.entries(coreResult.archives), func(x :(Principal, Vec.Vector<TransactionRange>)):  Service.ArchivedBlock{
          {
            args = Vec.toArray(x.1);
            callback = (actor(Principal.toText(x.0)) : MigrationTypes.Current.ICRC3Interface).icrc3_get_blocks;
          }
        }));
      };
    };
    /// Legacy version of get_blocks that returns transactions in the legacy format
    ///
    /// This function uses the same core logic as get_blocks but converts the results
    /// to legacy transaction format and uses legacy archive callbacks.
    ///
    /// Arguments:
    /// - `args`: The GetBlocksRequest range
    ///
    /// Returns:
    /// - Legacy transaction response with converted transactions
    public func get_blocks_legacy(args: Legacy.GetBlocksRequest) : Legacy.GetTransactionsResponse {
      // Convert single request to array format expected by core function
      let coreArgs = [{start = args.start; length = args.length}];
      let coreResult = get_blocks_core(coreArgs);
      
      // Convert ICRC-3 blocks to legacy transactions
      let blockValues = Array.map<{id: Nat; block: Value}, Value>(Vec.toArray(coreResult.blocks), func(item) = item.block);
      let legacyTransactions = Legacy.convertICRC3ToLegacyTransaction(blockValues);
      
      // Convert archives to legacy format
      let legacyArchives = Array.map<(Principal, Vec.Vector<TransactionRange>), Legacy.LegacyArchivedRange>(
        Iter.toArray(Map.entries(coreResult.archives)), 
        func(archiveEntry: (Principal, Vec.Vector<TransactionRange>)): Legacy.LegacyArchivedRange {
          let ranges = Vec.toArray(archiveEntry.1);
          // For legacy, we need to flatten multiple ranges into single start/length
          // Taking the first range as legacy format expects single range
          let firstRange = if (ranges.size() > 0){ ranges[0] } else {{start = 0; length = 0}};
          
          {
            callback = (actor(Principal.toText(archiveEntry.0)) : actor {
              get_transactions: shared query (Legacy.GetBlocksRequest) -> async Legacy.GetArchiveTransactionsResponse;
            }).get_transactions;
            start = firstRange.start;
            length = firstRange.length;
          };
        } 
      );
      
      debug if(debug_channel.get_transactions) D.print("Returning legacy transactions result" # debug_show(coreResult.ledger_length, coreResult.first_index, state.firstIndex, Map.size(coreResult.archives)));

      return {
        first_index = switch(coreResult.first_index){
          case(null) state.firstIndex;
          case(?val) val;
        };
        log_length = coreResult.ledger_length;
        transactions = legacyTransactions;
        archived_transactions = legacyArchives;
      };
    };
  };
}