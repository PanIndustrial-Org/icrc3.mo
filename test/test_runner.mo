import LegacyTest "legacy.test";

actor {
  public func run_tests() : async Text {
    LegacyTest.run_tests();
    "Tests completed - check debug output"
  };
}
