// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Ballot} from "src/Voting.sol";

contract DeployBallot is Script {
    function run() external {
        vm.startBroadcast();
        new Ballot();
        vm.stopBroadcast();
    }
}
