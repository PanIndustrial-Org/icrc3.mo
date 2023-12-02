dfx canister create --all
dfx ledger fabricate-cycles --cycles 1000000000000000 --canister test_runner
dfx deploy test_runner
dfx canister call test_runner test
