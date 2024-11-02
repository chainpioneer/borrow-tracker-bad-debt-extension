// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {BorrowTrackerBadDebtExtension} from "../src/BorrowTrackerBadDebtExtension.sol";

contract CounterScript is Script {
    BorrowTrackerBadDebtExtension public tracker;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        tracker = new BorrowTrackerBadDebtExtension(address(0));

        vm.stopBroadcast();
    }
}
