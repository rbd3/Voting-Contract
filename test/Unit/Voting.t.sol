// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
//import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Ballot} from "src/Voting.sol";

contract BallotTest is Test {
    Ballot public ballot;
}
