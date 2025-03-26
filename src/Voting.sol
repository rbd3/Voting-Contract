// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Ballot contract
 * @author Andry Narson
 * @notice This contract is for creating a sample Ballot
 * @dev implements voting sistem
 */

contract Ballot {

    struct Voter {
        uint256 weight;
        uint256 vote;
        address delegate;
        bool voted;
    }

    struct Proposal {
        bytes32 name;
        uint256 voteCount;
    }

    address private immutable chairperson;
    mapping(address => Voter) public voters;
    Proposal[] public proposals;
    uint256[] public tiedProposals;
    uint256 private constant VOTE_WEIGHT = 1;

    /* Event */
    event Voted(address indexed voter, uint256 proposal);
    event WinningProposalsCalculated(uint256[] tiedProposals);

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

    constructor(bytes32[] memory proposalNames) {
        uint256 proposalNamesLength = proposalNames.length;
        require( proposalNamesLength > 0, Ballot__NoProposaleProvided());
        chairperson = msg.sender;
        voters[chairperson].weight = VOTE_WEIGHT;

        for (uint256 i = 0; i < proposalNamesLength; i++) {
            for (uint256 j = i + 1; j < proposalNamesLength; j++) {
                require(proposalNames[i] != proposalNames[j], Ballot__DuplicateProposalName());
            }
            proposals.push(Proposal({name: proposalNames[i], voteCount: 0}));
        }
    }

    modifier onlyChairperson(){
require(msg.sender == chairperson, Ballot__OnlyChairpersonCanGiveRightToVote());
_;
    }

    function giveRightToVote(address _to) external onlyChairperson {
        require(voters[_to].weight == 0);
        
        require(!voters[_to].voted, Ballot__VoterAlreadyVoted());
        voters[_to].weight = VOTE_WEIGHT;
    }

    function delegate(address _to) external {
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, Ballot__YouHaveNoRightToVote());
        require(!sender.voted, Ballot__VoterAlreadyVoted());
        require(_to != msg.sender, Ballot__SelfDelegationIsntAllowed());

        while (voters[_to].delegate != address(0)) {
            _to = voters[_to].delegate;
            require(_to != msg.sender, Ballot__FoundLoopInDelegation());
        }

        Voter storage _delegate = voters[_to];
        uint256 weightToTransfer = sender.weight;
        //voter cannot delegate to account can't vote
        require(_delegate.weight >= VOTE_WEIGHT);
        sender.weight = 0;
        sender.voted = true;
        sender.delegate = _to;

        if (_delegate.voted) {
            proposals[_delegate.vote].voteCount += weightToTransfer;
        } else {
            _delegate.weight += weightToTransfer;
        }
    }

    function vote(uint256 proposal) external {
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, Ballot__YouHaveNoRightToVote());
        require(!sender.voted, Ballot__VoterAlreadyVoted());
        require(proposal < proposals.length, Ballot__InvalidProposalIndex());

        sender.vote = proposal;
        sender.voted = true;
        proposals[proposal].voteCount += sender.weight;
        emit Voted(msg.sender, proposal);
    }

    function calculateWinningProposals() external {
        require(msg.sender == chairperson, Ballot__OnlychairpersonCanCalculateWinningProposals());
        uint256 winningVoteCount = 0;
        delete tiedProposals; // Clear existing ties
        uint256 proposalCount = proposals.length;

        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].voteCount > winningVoteCount) {
                winningVoteCount = proposals[i].voteCount;
                tiedProposals = [i]; // Reset to a new array with the current proposal
            } else if (proposals[i].voteCount == winningVoteCount) {
                tiedProposals.push(i); // Add to the existing array
            }
        }
        emit WinningProposalsCalculated(tiedProposals);
    }

    function getWinningProposals() public view returns (uint256[] memory) {
        return tiedProposals;
    }

    function winnerName() external view returns (bytes32[] memory) {
        uint256 tiedProposalsLength = tiedProposals.length;
        bytes32[] memory winnerNames = new bytes32[](tiedProposals.length);
        for (uint256 i = 0; i < tiedProposalsLength; i++) {
            winnerNames[i] = proposals[tiedProposals[i]].name;
        }
        return winnerNames;
    }

    function getChairperson() external view returns (address) {
        return chairperson;
    }

    function getProposalsLength() public view returns (uint256) {
        return proposals.length;
    }
}
