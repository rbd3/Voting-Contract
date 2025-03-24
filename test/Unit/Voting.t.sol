// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployBallot} from "script/DeployBallot.s.sol";
import {Ballot} from "src/Voting.sol";

/* Error */
error Ballot__NoProposaleProvided();
error Ballot__DuplicateProposalName();
error Ballot__YouAlreadyVoted();
error Ballot__OnlyChairpersonCanGiveRightToVote();
error Ballot__VoterAlreadyVoted();
error Ballot__YouHaveNoRightToVote();
error Ballot__SelfDelegationIsntAllowed();
error Ballot__FoundLoopInDelegation();
error Ballot__InvalidProposalIndex();
error Ballot__OnlychairpersonCanCalculateWinningProposals();

contract BallotTest is Test {
    Ballot public ballot;
    address chairperson = address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38); // Example chairperson address

    // Set up the test environment
    function setUp() external {
        // Create an array of proposal names
        bytes32[] memory proposalNames = new bytes32[](3);
        proposalNames[0] = bytes32("Proposal A");
        proposalNames[1] = bytes32("Proposal B");
        proposalNames[2] = bytes32("Proposal C");

        // Deploy the Ballot contract using the DeployBallot script
        DeployBallot deployer = new DeployBallot();
        ballot = deployer.deploy(proposalNames);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    // Test successful deployment with valid proposal names
    function testConstructor_Success() public view {
        // Check if the chairperson is set correctly
        assertEq(ballot.chairperson(), chairperson);

        // Check if proposals are initialized correctly
        (bytes32 name0, ) = ballot.proposals(0);
        assertEq(name0, bytes32("Proposal A"));

        (uint256 weight, , , ) = ballot.voters(chairperson);
        assertEq(weight, 1);
    }

    function testConstructor_Revert() public {
        // Create an array of proposal names
        bytes32[] memory proposalNames = new bytes32[](3);
        proposalNames[0] = bytes32("Proposal A");
        proposalNames[1] = bytes32("Proposal B");
        proposalNames[2] = bytes32("Proposal C");
        proposalNames[2] = bytes32("Proposal A");

        vm.expectRevert(Ballot__DuplicateProposalName.selector);
        ballot = new Ballot(proposalNames);
    }

    // Test deployment with no proposal names (should revert)
    function testConstructor_NoProposals() public {
        bytes32[] memory proposalNames = new bytes32[](0); // Empty proposal array

        // Expect revert with the correct error message
        vm.expectRevert(Ballot__NoProposaleProvided.selector);
        ballot = new Ballot(proposalNames);
    }
}
