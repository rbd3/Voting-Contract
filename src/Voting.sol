// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Ballot {
    /*
    struct voter, proposal
    function give right to vote, delegate vote, winning proposal, winner name,
    event voted
    */

    struct Voter {
        uint weight;
        uint vote;
        address delegate;
        bool voted;
    }
    struct Proposal {
        bytes32 name;
        uint voteCount;
    }

    address public chairperson;
    mapping(address => Voter) public voters;
    Proposal[] public proposals;
    uint[] public tiedProposals;

    /* Event */
    event Voted(address indexed voter, uint proposal);
    event WinningProposalsCalculated(uint[] tiedProposals);

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
        require(proposalNames.length > 0, "No proposals provided");
        chairperson = msg.sender;
        voters[chairperson].weight = 1;

        for (uint i = 0; i < proposalNames.length; i++) {
            for (uint j = i + 1; j < proposalNames.length; j++) {
                require(
                    proposalNames[i] != proposalNames[j],
                    "Duplicate proposal name"
                );
            }
            proposals.push(Proposal({name: proposalNames[i], voteCount: 0}));
        }
    }

    function giveRightToVote(address _to) external {
        require(voters[_to].weight == 0);
        require(
            msg.sender != chairperson,
            Ballot__OnlyChairpersonCanGiveRightToVote()
        );
        require(!voters[_to].voted, Ballot__VoterAlreadyVoted());
        voters[_to].weight = 1;
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
        //voter cannot delegate to account can't vote
        require(_delegate.weight >= 1);

        sender.voted = true;
        sender.delegate = _to;

        if (_delegate.voted) {
            // If the delegate did not vote yet,
            // add to her weight.
            proposals[_delegate.vote].voteCount += sender.weight;
        } else {
            _delegate.weight += sender.weight;
        }
    }

    //Asign all voter at once
    function giveRightToVoteForAll(address[] memory voterAdress) external {
        require(
            msg.sender == chairperson,
            Ballot__OnlyChairpersonCanGiveRightToVote()
        );

        for (uint i = 0; i < voterAdress.length; i++) {
            address voter = voterAdress[i];

            require(!voters[voter].voted, Ballot__VoterAlreadyVoted());
            require(voters[voter].weight == 0);
            voters[voter].weight = 1;
        }
    }
    function vote(uint proposal) external {
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, Ballot__YouHaveNoRightToVote());
        require(!sender.voted, Ballot__VoterAlreadyVoted());
        require(proposal < proposals.length, Ballot__InvalidProposalIndex());

        sender.vote = proposal;
        sender.voted = true;
        proposals[proposal].voteCount += sender.weight;
        emit Voted(msg.sender, proposal);
    }

    function calculateWinningProposals() public {
        require(
            msg.sender == chairperson,
            Ballot__OnlychairpersonCanCalculateWinningProposals()
        );
        uint winningVoteCount = 0;
        delete tiedProposals; // Clear existing ties
        uint proposalCount = proposals.length;

        for (uint i = 0; i < proposalCount; i++) {
            if (proposals[i].voteCount > winningVoteCount) {
                winningVoteCount = proposals[i].voteCount;
                tiedProposals = [i]; // Reset to a new array with the current proposal
            } else if (proposals[i].voteCount == winningVoteCount) {
                tiedProposals.push(i); // Add to the existing array
            }
        }
        emit WinningProposalsCalculated(tiedProposals);
    }

    function getWinningProposals() public view returns (uint[] memory) {
        return tiedProposals;
    }

    function winnerName() external view returns (bytes32[] memory) {
        bytes32[] memory winnerNames = new bytes32[](tiedProposals.length);
        for (uint i = 0; i < tiedProposals.length; i++) {
            winnerNames[i] = proposals[tiedProposals[i]].name;
        }
        return winnerNames;
    }
}
