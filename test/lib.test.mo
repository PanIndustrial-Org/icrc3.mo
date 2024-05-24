
//test against stable memory are currently under development

import Rosetta "../src/utils/Rosetta";
import Principal "mo:base/Principal";
import D "mo:base/Debug";
import Text "mo:base/Text";

let transfer = #Map([
  ("ts", #Nat(1000)),
  ("btype", #Text("1xfer")),
  ("tx", #Map([
    ("op", #Text("1xfer")),
    ("fee", #Nat(10000)),
    ("amount", #Nat(210000)),
    ("ts", #Nat(30000)),
    ("from", #Array([#Blob(Principal.toBlob(Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe")))])),
    ("to", #Array([#Blob(Principal.toBlob(Principal.fromText("agtsn-xyaaa-aaaag-ak3kq-cai"))), #Blob(Text.encodeUtf8("to"))])),
  ])),
]);

let transferWithMemo = #Map([
  ("ts", #Nat(1000)),
  ("btype", #Text("1xfer")),
  ("tx", #Map([
    ("op", #Text("1xfer")),
    ("fee", #Nat(10000)),
    ("amount", #Nat(210000)),
    ("ts", #Nat(30000)),
    ("memo", #Blob(Text.encodeUtf8("HelloWorld"))),
    ("from", #Array([#Blob(Principal.toBlob(Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe")))])),
    ("to", #Array([#Blob(Principal.toBlob(Principal.fromText("agtsn-xyaaa-aaaag-ak3kq-cai"))), #Blob(Text.encodeUtf8("to"))])),
  ])),
]);


let parsedTransfer = Rosetta.blockToTransaction(transfer);
D.print("parsedTransfer " # debug_show((parsedTransfer, do?{parsedTransfer!.transfer!.to.subaccount})));
assert(parsedTransfer != null);
assert((do?{parsedTransfer!.transfer}) != null);
assert((do?{parsedTransfer!.transfer!.amount}) == ?210000);
assert((do?{parsedTransfer!.transfer!.fee!}) == ?10000);
assert((do?{parsedTransfer!.transfer!.created_at_time!}) == ?30000);
assert((do?{parsedTransfer!.transfer!.memo!}) == null);
assert((do?{parsedTransfer!.transfer!.from.owner}) == ?Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe"));
assert((do?{parsedTransfer!.transfer!.from.subaccount!})) == null;
assert((do?{parsedTransfer!.transfer!.to.owner}) == ?Principal.fromText("agtsn-xyaaa-aaaag-ak3kq-cai"));
assert((do?{parsedTransfer!.transfer!.to.subaccount!})) == ?Text.encodeUtf8("to");


let parsedTransferWithMemo = Rosetta.blockToTransaction(transferWithMemo);
D.print("parsedTransferWithMemo " # debug_show(parsedTransferWithMemo));
assert(parsedTransferWithMemo != null);
assert((do?{parsedTransferWithMemo!.transfer!.memo!}) == ?Text.encodeUtf8("HelloWorld"));




// Test 1mint transaction
let mint = #Map([
  ("ts", #Nat(1000)),
  ("btype", #Text("1mint")),
  ("tx", #Map([
    ("op", #Text("1mint")),
    ("amount", #Nat(500000)),
    ("ts", #Nat(30000)),
    ("to", #Array([#Blob(Principal.toBlob(Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe")))])),
  ])),
]);

let parsedMint = Rosetta.blockToTransaction(mint);
D.print("parsedMint " # debug_show(parsedMint));
assert(parsedMint != null);
assert((do?{parsedMint!.mint}) != null);
assert((do?{parsedMint!.mint!.amount}) == ?500000);
assert((do?{parsedMint!.mint!.to.owner}) == ?Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe"));
assert((do?{parsedMint!.mint!.to.subaccount!})) == null;

// Test 1burn transaction
let burn = #Map([
  ("ts", #Nat(1000)),
  ("btype", #Text("1burn")),
  ("tx", #Map([
    ("op", #Text("1burn")),
    ("amount", #Nat(200000)),
    ("ts", #Nat(30000)),
    ("from", #Array([#Blob(Principal.toBlob(Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe")))])),
  ])),
]);

let parsedBurn = Rosetta.blockToTransaction(burn);
D.print("parsedBurn " # debug_show(parsedBurn));
assert(parsedBurn != null);
assert((do?{parsedBurn!.burn}) != null);
assert((do?{parsedBurn!.burn!.amount}) == ?200000);
assert((do?{parsedBurn!.burn!.from.owner}) == ?Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe"));
assert((do?{parsedBurn!.burn!.from.subaccount!})) == null;

// Test 2xfer transaction
let xfer = #Map([
  ("ts", #Nat(1000)),
  ("btype", #Text("2xfer")),
  ("tx", #Map([
    ("op", #Text("2xfer")),
    ("amount", #Nat(300000)),
    ("ts", #Nat(30000)),
    ("from", #Array([#Blob(Principal.toBlob(Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe")))])),
    ("to", #Array([#Blob(Principal.toBlob(Principal.fromText("agtsn-xyaaa-aaaag-ak3kq-cai")))])),
  ])),
]);

let parsedXfer = Rosetta.blockToTransaction(xfer);
D.print("parsedXfer " # debug_show(parsedXfer));
assert(parsedXfer != null);
assert((do?{parsedXfer!.transfer}) != null);
assert((do?{parsedXfer!.transfer!.amount}) == ?300000);
assert((do?{parsedXfer!.transfer!.from.owner}) == ?Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe"));
assert((do?{parsedXfer!.transfer!.to.owner}) == ?Principal.fromText("agtsn-xyaaa-aaaag-ak3kq-cai"));
assert((do?{parsedXfer!.transfer!.from.subaccount!})) == null;
assert((do?{parsedXfer!.transfer!.to.subaccount!})) == null;

// Test 2approve transaction
let approve = #Map([
  ("ts", #Nat(1000)),
  ("btype", #Text("2approve")),
  ("tx", #Map([
    ("op", #Text("2approve")),
    ("amount", #Nat(400000)),
    ("ts", #Nat(30000)),
    ("from", #Array([#Blob(Principal.toBlob(Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe")))])),
    ("spender", #Array([#Blob(Principal.toBlob(Principal.fromText("agtsn-xyaaa-aaaag-ak3kq-cai")))])),
  ])),
]);

let parsedApprove = Rosetta.blockToTransaction(approve);
D.print("parsedApprove " # debug_show(parsedApprove));
assert(parsedApprove != null);
assert((do?{parsedApprove!.approve}) != null);
assert((do?{parsedApprove!.approve!.amount}) == ?400000);
assert((do?{parsedApprove!.approve!.from.owner}) == ?Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe"));
assert((do?{parsedApprove!.approve!.spender.owner}) == ?Principal.fromText("agtsn-xyaaa-aaaag-ak3kq-cai"));
assert((do?{parsedApprove!.approve!.from.subaccount!})) == null;
assert((do?{parsedApprove!.approve!.spender.subaccount!})) == null;
