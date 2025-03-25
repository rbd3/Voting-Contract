// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Ballot} from "src/Voting.sol";

contract DeployBallot is Script {
    // This function is used for deployment in scripts
    function run() external {
        bytes32[] memory proposalNames = new bytes32[](3);
        proposalNames[0] = bytes32("Proposal A");
        proposalNames[1] = bytes32("Proposal B");
        proposalNames[2] = bytes32("Proposal C");

        vm.startBroadcast();
        new Ballot(proposalNames);
        vm.stopBroadcast();
    }

    // This function is used for deployment in tests
    function deploy(bytes32[] memory proposalNames) public returns (Ballot) {
        vm.startBroadcast();
        Ballot ballot = new Ballot(proposalNames);
        vm.stopBroadcast();
        return ballot;
    }
}
