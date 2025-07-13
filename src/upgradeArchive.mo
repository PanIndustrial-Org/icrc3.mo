import Archive "./archive";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Principal "mo:base/Principal";


module {
   public func upgradeArchive<system>(canisters: [Principal]) : async [Result.Result<(),Text>]{

    let result = Buffer.Buffer<Result.Result<(),Text>>(canisters.size());
    label proc for(thisCanister in canisters.vals()){
      try{
        //note: args is stable in archive so these init items are a noop
        await (system Archive)(#upgrade(canisterId))({
          maxRecords = 0;
          maxPages = 62500;
          indexType = #Stable;
          firstIndex = 0;
        })
      }catch(e){
        result.push(#err("Failed to upgrade archive canister " # Principal.toText(thisCanister) # ": " # Error.message(e)));
      }
      result.push(#ok(()));
    };
    return Buffer.toArray(result);

   };
}