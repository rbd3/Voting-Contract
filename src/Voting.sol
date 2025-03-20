// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Ballot {
    /*
    struct voter, proposal
    function give right to vote, delegate vote, winning proposal, winner name,
    event voted
    */

    struct Voter{
        uint256 weight,
        uint vote,
        address delegate,
        bool voted
    }
    struct Proposal{
        bytes32 name,
        uint voteCount
    }

    address public chairperson;
    mapping(uint256=>Voter) public voters;
    Proposals[] public proposals;

    /* Error */
    error Ballot__NoProposaleProvided();

    constructor(bytes32 memory proposaleName){
        require(proposaleName.length > 0, Ballot__NoProposaleProvided());
        chairperson = msg.sender;
        voters[chairperson].weight = 1;
        for(uint i = 0; i < proposalNames.length; i++) {
            for (uint j = i + 1; j < proposalNames.length; j++) { //Ensure proposal names are unique to prevent ambiguity.
            require(proposalNames[i] != proposalNames[j], "Duplicate proposal names");
        }
        proposals.push(Proposal({
            name: proposalNames[i],
            voteCount: 1
        }));
    }
}
