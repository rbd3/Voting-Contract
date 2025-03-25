// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {Ballot} from "src/Voting.sol";
import {DeployBallot} from "script/DeployBallot.s.sol";

contract BallotIntegrationTest is Test {
    DeployBallot deployer;
    Ballot ballot;
    address chairperson = address(1);
    address[] voters = [address(2), address(3), address(4)];

    function setUp() public {
        // Don't use prank during deployment
        deployer = new DeployBallot();

        // Initialize with 3 proposals
        bytes32[] memory proposalNames = new bytes32[](3);
        proposalNames[0] = "Proposal 1";
        proposalNames[1] = "Proposal 2";
        proposalNames[2] = "Proposal 3";

        ballot = deployer.deploy(proposalNames);

        // Set chairperson if needed (assuming the deployer becomes chairperson)
        chairperson = address(ballot.getChairperson());
    }

    function testFullVotingWorkflow() public {
        // Phase 1: Register Voters
        vm.startPrank(chairperson);
        for (uint256 i = 0; i < voters.length; i++) {
            ballot.giveRightToVote(voters[i]);
        }
        vm.stopPrank();

        // Phase 2: Cast Votes
        vm.prank(voters[0]);
        ballot.vote(0); // Voter 0 votes Proposal 1

        vm.prank(voters[1]);
        ballot.vote(1); // Voter 1 votes Proposal 2

        // Voter 2 delegates to Voter 1
        vm.prank(voters[2]);
        ballot.delegate(voters[1]);

        // Phase 3: Calculate Results
        vm.prank(chairperson);
        ballot.calculateWinningProposals();

        // Phase 4: Verify Results
        bytes32[] memory winners = ballot.winnerName();

        // Proposal 2 should win (voters[1]'s vote + voters[2]'s delegated vote)
        assertEq(winners.length, 1, "Should have exactly one winner");
        assertEq(winners[0], "Proposal 2", "Proposal 2 should win");

        // Verify vote counts
        (, uint256 prop0Votes) = ballot.proposals(0);
        (, uint256 prop1Votes) = ballot.proposals(1);
        (, uint256 prop2Votes) = ballot.proposals(2);

        assertEq(prop0Votes, 1, "Proposal 1 should have 1 vote");
        assertEq(prop1Votes, 2, "Proposal 2 should have 2 votes");
        assertEq(prop2Votes, 0, "Proposal 3 should have 0 votes");
    }

    function testTieScenario() public {
        // Setup voters
        vm.startPrank(chairperson);
        for (uint256 i = 0; i < voters.length; i++) {
            ballot.giveRightToVote(voters[i]);
        }
        vm.stopPrank();

        // Create tie between Proposal 0 and 1
        vm.prank(voters[0]);
        ballot.vote(0);

        vm.prank(voters[1]);
        ballot.vote(1);

        // Third voter doesn't vote (abstains)

        // Calculate results
        vm.prank(chairperson);
        ballot.calculateWinningProposals();

        // Verify tie
        bytes32[] memory winners = ballot.winnerName();
        assertEq(winners.length, 2, "Should have two tied winners");
        assertEq(winners[0], "Proposal 1");
        assertEq(winners[1], "Proposal 2");
    }
}
