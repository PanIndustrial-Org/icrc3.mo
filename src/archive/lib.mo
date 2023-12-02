import SW "mo:stable-write-only";
import T "../migrations/types";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Vec "mo:vector";
import D "mo:base/Debug";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";

shared ({ caller = ledger_canister_id }) actor class Archive (_args : T.Current.ArchiveInitArgs) = this {

    D.print("new archive created with the following args" # debug_show(_args));

    type Transaction = T.Current.Transaction;
    type MemoryBlock = {
        offset : Nat64;
        size : Nat;
    };

    public type InitArgs = T.Current.ArchiveInitArgs;

    public type AddTransactionsResponse = T.Current.AddTransactionsResponse;
    public type TransactionRange = T.Current.TransactionRange;

    stable var args = _args;

    stable var memstore = SW.init({
      maxRecords = args.maxRecords;
      indexType = args.indexType;
      maxPages = 62500;
    });

    let sw = SW.StableWriteOnly(?memstore);

    public shared ({ caller }) func append_transactions(txs : [Transaction]) : async AddTransactionsResponse {

      D.print("adding transactions to archive" # debug_show(txs));

        if (caller != ledger_canister_id) {
            return #err("Unauthorized Access: Only the ledger canister can access this archive canister");
        };

      label addrecs for(thisItem in txs.vals()){
        let stats = sw.stats();
        if(stats.itemCount >= args.maxRecords){
          D.print("braking add recs");
          break addrecs;
        };
        ignore sw.write(to_candid(thisItem));
      };

      let final_stats = sw.stats();
      if(final_stats.itemCount >= args.maxRecords){
        return #Full(final_stats);
      };
      #ok(final_stats);
    };

    func total_txs() : Nat {
        sw.stats().itemCount;
    };

    public shared query func total_transactions() : async Nat {
        total_txs();
    };

    public shared query func get_transaction(tx_index : T.Current.TxIndex) : async ?Transaction {
        
        return _get_transaction(tx_index);
    };

    private func _get_transaction(tx_index : T.Current.TxIndex) : ?Transaction {
        let stats = sw.stats();
        D.print("getting transaction" # debug_show(tx_index, args.firstIndex, stats));
       
        let target_index =  if(tx_index >= args.firstIndex) Nat.sub(tx_index, args.firstIndex) else D.trap("Not on this canister requested " # Nat.toText(tx_index) # "first index: " # Nat.toText(args.firstIndex));
        D.print("target" # debug_show(target_index));
        if(target_index >= stats.itemCount) D.trap("requested an item outside of this archive canister. first index: " # Nat.toText(args.firstIndex) # " last item" # Nat.toText(args.firstIndex + stats.itemCount - 1));
        D.print("target" # debug_show(target_index));
        let t = from_candid(sw.read(target_index)) : ?Transaction;
        return t;
    };

    public shared query func icrc3_get_blocks(req : T.Current.TransactionRange) : async T.Current.GetTransactionsResult {

      D.print("request for archive blocks " # debug_show(req));

      let vec = Vec.new<{id:Nat; transaction: Transaction}>();
      var tracker = req.start;
      for(thisItem in Iter.range(req.start, req.start + req.length - 1)){
        D.print("getting" # debug_show(thisItem));
        switch(_get_transaction(thisItem)){
          case(null){
            //should be unreachable...do we return an error?
          };
          case(?val){
            D.print("found" # debug_show(val));
            Vec.add(vec, {id = tracker; transaction = val});
          };
        };
        tracker += 1;
      };

      { 
          blocks = Vec.toArray(vec);
          archived_blocks = [];
          log_length =  0;
          certificate = null;
        };
       /*  let { start; length } = req;

        D.print("had a call to the archive for " # debug_show(req));
        
        let vec = Vec.new<{id:Nat; transaction: Transaction}>();

        let end = start + length - args.firstIndex;
        var tracker = start - args.firstIndex;
        let stats = sw.stats();

        D.print("had a call to the archive for " # debug_show(end, tracker, stats));
        

        label build loop{
          let ?t = (from_candid(sw.read(tracker)) : ?Transaction);
          Vec.add(vec, {id =tracker + args.firstIndex; transaction = t});
          if(tracker >= stats.itemCount or tracker >= end) break build;
        };

        { 
          blocks = Vec.toArray(vec);
          archived_blocks = [];
          log_length =  0;
          certificate = null;
        }; */
      /* let stats = sw.stats();
        D.print("get_transaction_states" # debug_show(stats));
      let local_ledger_length = stats.itemCount;
      let last_index = args.firstIndex + local_ledger_length;


      //get the transactions on this canister
      let vec = Vec.new<{id:Nat; transaction: Transaction}>();
      D.print("setting start " # debug_show(req.start + req.length, args.firstIndex));
      if(req.start + req.length > args.firstIndex){
        D.print("setting start " # debug_show(req.start + req.length, args.firstIndex));
        let start = if(req.start <= args.firstIndex){
          D.print("setting start " # debug_show(0));
          0;
        } else{
         
          last_index - args.firstIndex + 1;
        };

        let end = if(local_ledger_length==0){
          0;
        } else if(req.start + req.length >= last_index){
          local_ledger_length - 1;
        } else {
          (last_index - args.firstIndex) - (last_index - (req.start + req.length))
        };

        D.print("getting local transactions" # debug_show(start,end));
        //some of the items are on this server
        if(local_ledger_length > 0){
          label search for(thisItem in Iter.range(start, end)){
            D.print("testing" # debug_show(thisItem));
            if(thisItem >= Vec.size(state.ledger)){
              break search;
            };
            Vec.add(vec, {
                id = args.firstIndex + thisItem;
                transaction = Vec.get(state.ledger, thisItem)
            });
          };
        };

      };

      D.print("returning transactions result" # debug_show( Vec.size(vec)));
      //build the result
      return {
        log_length = 0;
        certificate = null;
        blocks = Vec.toArray(vec);
        archived_blocks = [];
      } */
    };

    public shared query func remaining_capacity() : async Nat {
        args.maxRecords - sw.stats().itemCount;
    };

    /// Deposit cycles into this archive canister.
    public shared func deposit_cycles() : async () {
        let amount = ExperimentalCycles.available();
        let accepted = ExperimentalCycles.accept(amount);
        assert (accepted == amount);
    };

};