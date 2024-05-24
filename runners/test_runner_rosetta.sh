dfx canister create --all
dfx ledger fabricate-cycles --cycles 1000000000000000 --canister test_runner_rosetta
dfx deploy test_runner_rosetta
dfx canister call test_runner_rosetta test
