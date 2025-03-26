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

/* Event */
event Voted(address indexed voter, uint256 proposal);

event WinningProposalsCalculated(uint256[] tiedProposals);

contract BallotTest is Test {
    Ballot public ballot;
    address chairperson = address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38); // Example chairperson address
    uint256[] public tiedProposals;

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
        assertEq(ballot.getChairperson(), chairperson);

        // Check if proposals are initialized correctly
        (bytes32 name0,) = ballot.proposals(0);
        assertEq(name0, bytes32("Proposal A"));

        (uint256 weight,,,) = ballot.voters(chairperson);
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

        vm.expectRevert(Ballot__NoProposaleProvided.selector);
        ballot = new Ballot(proposalNames);
    }

    /*//////////////////////////////////////////////////////////////
                           GETTERS
    //////////////////////////////////////////////////////////////*/

    function testgetChairperson() public view {
        assertEq(ballot.getChairperson(), chairperson);
    }

    function testgetProposalLenth() public view {
        assertEq(ballot.getProposalsLength(), 3);
    }

    /*//////////////////////////////////////////////////////////////
                            GIVE RIGHT TO VOTE
    //////////////////////////////////////////////////////////////*/

    function testgiveRightToVoteOnlyChairperson() public {
        address _to = address(0x47e179EC197488593B187f80A00eb0dA91f1b9d0);

        // Simulate a non-chairperson calling the function
        vm.prank(address(0x12354));
        vm.expectRevert(Ballot__OnlyChairpersonCanGiveRightToVote.selector);
        ballot.giveRightToVote(_to);
    }

    function testgiveRightToVoteInitialWeight() public {
        address _to = address(0x47e179EC197488593B187f80A00eb0dA91f1b9d0);

        vm.prank(chairperson);
        ballot.giveRightToVote(_to);
        (uint256 weight,,,) = ballot.voters(_to);
        assertEq(weight, 1); //Voter should have a weight of 1 after call giveRightToVote

        // Attempt to give rights again - should revert
        vm.prank(chairperson);
        vm.expectRevert();
        ballot.giveRightToVote(_to);
    }

    function testgiveRightToVoteAlreadyVoted() public {
        // Use a valid Ethereum address with correct checksum
        address _to = address(0x47e179EC197488593B187f80A00eb0dA91f1b9d0);

        vm.prank(chairperson);
        ballot.giveRightToVote(_to);
        (,,, bool voted) = ballot.voters(_to);
        assertEq(voted, false); //Voter should have a 0 vote
    }

    /*//////////////////////////////////////////////////////////////
                                  VOTE
    //////////////////////////////////////////////////////////////*/

    function testCannotVoteForInvalidProposal() public {
        // Setup a voter with voting rights
        address voter = address(0x123);
        vm.prank(chairperson);
        ballot.giveRightToVote(voter);

        // Get the number of proposals
        uint256 invalidProposalIndex = ballot.getProposalsLength(); // This will be out of bounds

        // Attempt to vote for invalid proposal
        vm.prank(voter);
        vm.expectRevert(Ballot__InvalidProposalIndex.selector);
        ballot.vote(invalidProposalIndex);
    }

    function testVoteProposal() public {
        address voter = address(0x123);

        vm.prank(chairperson);
        ballot.giveRightToVote(voter);

        vm.prank(voter);
        ballot.vote(1);
        (, uint256 vote,,) = ballot.voters(voter);
        assertEq(vote, 1);
    }

    function testVoteLastProposal() public {
        address voter = address(0x125);
        vm.prank(chairperson);
        ballot.giveRightToVote(voter);

        uint256 lastProposalIndex = ballot.getProposalsLength() - 1;
        vm.prank(voter);
        ballot.vote(lastProposalIndex);

        (, uint256 votedProposal,, bool votedStatus) = ballot.voters(voter);
        assertEq(votedProposal, lastProposalIndex);
        assertTrue(votedStatus, "Should mark voter as voted");

        vm.prank(voter);
        vm.expectRevert(Ballot__VoterAlreadyVoted.selector);
        ballot.vote(0);
    }

    function testCannotVoteWithoutVotingRights() public {
        address voter = address(0x125);

        vm.prank(voter);
        vm.expectRevert(Ballot__YouHaveNoRightToVote.selector);
        ballot.vote(0);
    }

    /*//////////////////////////////////////////////////////////////
                            WINNING PROPOSAL
    //////////////////////////////////////////////////////////////*/

    function testCalculateWinningProposalOnlyChairperson() public {
        address nonChairperson = address(1);

        vm.prank(nonChairperson);
        vm.expectRevert(Ballot__OnlychairpersonCanCalculateWinningProposals.selector);
        ballot.calculateWinningProposals();
    }

    function testCalculateWinningProposalSucceedsWhenChairperson() public {
        // Give voting rights and cast some votes
        address voter1 = address(0x123);
        vm.prank(chairperson);

        ballot.giveRightToVote(voter1);
        vm.prank(voter1);
        ballot.vote(0); // Vote for proposal 0

        address voter2 = address(0x242);
        vm.prank(chairperson);

        ballot.giveRightToVote(voter2);
        vm.prank(voter2);
        ballot.vote(0); // Vote for proposal 0 again

        uint256[] memory expectedTiedProposals = new uint256[](1);
        expectedTiedProposals[0] = 0;

        vm.prank(chairperson);

        vm.expectEmit(true, true, true, true);
        emit WinningProposalsCalculated(expectedTiedProposals);

        ballot.calculateWinningProposals();
    }

    function testWinningProposal() public {
        // Give voting rights and cast some votes
        address voter1 = address(0x123);
        vm.prank(chairperson);

        ballot.giveRightToVote(voter1);
        vm.prank(voter1);
        ballot.vote(0); // Vote for proposal 0

        address voter2 = address(0x242);
        vm.prank(chairperson);

        ballot.giveRightToVote(voter2);
        vm.prank(voter2);
        ballot.vote(0); // Vote for proposal 0 again

        uint256[] memory expectedTiedProposals = new uint256[](1);
        expectedTiedProposals[0] = 0;

        vm.prank(chairperson);
        ballot.calculateWinningProposals();
        assertEq(ballot.getWinningProposals(), expectedTiedProposals);
    }

    function testWinnerName() public {
        // Give voting rights and cast some votes
        address voter1 = address(0x123);
        vm.prank(chairperson);

        ballot.giveRightToVote(voter1);
        vm.prank(voter1);
        ballot.vote(0); // Vote for proposal 0

        address voter2 = address(0x242);
        vm.prank(chairperson);

        ballot.giveRightToVote(voter2);
        vm.prank(voter2);
        ballot.vote(0); // Vote for proposal 0 again

        vm.prank(chairperson);
        ballot.calculateWinningProposals();

        (bytes32 name0,) = ballot.proposals(0);
        bytes32[] memory winnerNames = ballot.winnerName();

        assertEq(winnerNames.length, 1);
        assertEq(winnerNames[0], name0);
    }

    /*//////////////////////////////////////////////////////////////
                                DELEGATE
    //////////////////////////////////////////////////////////////*/

    function testgiveNoRightToDelegateIfNoVote() public {
        address _to = address(0x47e179EC197488593B187f80A00eb0dA91f1b9d0);

        // Simulate a non-chairperson calling the function
        vm.prank(address(0x12354));
        vm.expectRevert(Ballot__YouHaveNoRightToVote.selector);
        ballot.delegate(_to);
    }

    function testDelegateToVoteAlreadyVoted() public {
        // Use a valid Ethereum address with correct checksum
        address _to = address(0x47e179EC197488593B187f80A00eb0dA91f1b9d0);

        vm.prank(chairperson);
        ballot.giveRightToVote(_to);
        (,,, bool voted) = ballot.voters(_to);
        vm.prank(chairperson);
        ballot.delegate(_to);
        assertEq(voted, false); //Voter should have a 0 vote
    }

    function testDelegateToVoteAlreadyVotedPerson() public {
        address voter1 = address(0x111);
        address voter2 = address(0x222);

        // Give voting rights to both
        vm.prank(chairperson);
        ballot.giveRightToVote(voter1);
        vm.prank(chairperson);
        ballot.giveRightToVote(voter2);

        // Make voter1 vote first
        vm.prank(voter1);
        ballot.vote(0);

        vm.prank(voter1);
        vm.expectRevert(Ballot__VoterAlreadyVoted.selector);
        ballot.delegate(voter2);
    }

    function testSelfDelegation() public {
        // Use a valid Ethereum address with correct checksum
        address _to = address(0x47e179EC197488593B187f80A00eb0dA91f1b9d0);

        vm.prank(chairperson);
        ballot.giveRightToVote(_to);
        vm.prank(chairperson);
        vm.expectRevert(Ballot__SelfDelegationIsntAllowed.selector);
        ballot.delegate(chairperson);
    }

    function testLoopInDelegation() public {
        address voterA = address(0x111);
        address voterB = address(0x222);
        address voterC = address(0x333);

        vm.startPrank(chairperson);
        ballot.giveRightToVote(voterA);
        ballot.giveRightToVote(voterB);
        ballot.giveRightToVote(voterC);
        vm.stopPrank();

        // Create delegation chain: A → B → C
        vm.prank(voterA);
        ballot.delegate(voterB);

        vm.prank(voterB);
        ballot.delegate(voterC);

        vm.prank(voterC);
        vm.expectRevert(Ballot__FoundLoopInDelegation.selector);
        ballot.delegate(voterA); // This should detect A→B→C→A loop
    }

    function testCannotDelegateToNonVoter() public {
        // Setup
        address voter = address(0x111);
        address nonVoter = address(0x222);

        // Give voting rights only to voter
        vm.prank(chairperson);
        ballot.giveRightToVote(voter);

        // Verify nonVoter has no weight
        (uint256 weight,,,) = ballot.voters(nonVoter);
        assertEq(weight, 0, "Non-voter should have 0 weight");

        // Attempt to delegate to non-voter (should revert)
        vm.prank(voter);
        vm.expectRevert(); // Should revert because _delegate.weight = 0
        ballot.delegate(nonVoter);
    }

    function testDelegationTransfersWeight() public {
        address voter1 = address(0x111);
        address voter2 = address(0x222);

        vm.startPrank(chairperson);
        ballot.giveRightToVote(voter1);
        ballot.giveRightToVote(voter2);
        vm.stopPrank();

        // Verify initial weights
        (uint256 weight1,,,) = ballot.voters(voter1);
        (uint256 weight2,,,) = ballot.voters(voter2);
        assertEq(weight1, 1);
        assertEq(weight2, 1);

        // Delegate
        vm.prank(voter1);
        ballot.delegate(voter2);

        // Verify weights after delegation
        (weight1,,,) = ballot.voters(voter1);
        (weight2,,,) = ballot.voters(voter2);
        // Check delegation was recorded
        (,, address delegate,) = ballot.voters(voter1);
        assertEq(delegate, voter2, "Delegation address not set correctly");
        assertEq(weight1, 0, "Delegator's weight should be 0");
        assertEq(weight2, 2, "Delegatee's weight should be 2");
    }

    function testDelegateToVotedVoter() public {
        // Setup voters
        address voterA = address(0xA);
        address voterB = address(0xB);

        // Give voting rights
        vm.startPrank(chairperson);
        ballot.giveRightToVote(voterA);
        ballot.giveRightToVote(voterB);
        vm.stopPrank();

        // Make voterB vote first
        vm.prank(voterB);
        ballot.vote(1); // Vote for proposal 1

        // Verify initial proposal votes
        (, uint256 proposal1VotesBefore) = ballot.proposals(1);

        // Delegate A → B (B already voted)
        vm.prank(voterA);
        ballot.delegate(voterB);

        // Verify weights
        (uint256 weightA,,,) = ballot.voters(voterA);
        (uint256 weightB,,,) = ballot.voters(voterB);
        assertEq(weightA, 0, "Delegator weight should be 0");
        assertEq(weightB, 1, "Delegatee weight should remain unchanged");

        // Verify vote count increased
        (, uint256 proposal1VotesAfter) = ballot.proposals(1);
        assertEq(
            proposal1VotesAfter, proposal1VotesBefore + 1, "Proposal vote count should increase by delegated weight"
        );
    }
}
