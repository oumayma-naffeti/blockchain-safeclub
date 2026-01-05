// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol";

contract SafeClub is Ownable, ReentrancyGuard {

    // ===== Membres =====
    mapping(address => bool) public isMember;
    address[] private members;

    event MemberAdded(address member);
    event MemberRemoved(address member);

    modifier onlyMember() {
        require(isMember[msg.sender], "Not a member");
        _;
    }

    // ===== Propositions =====
    struct Proposal {
        uint id;
        address payable to;
        uint amount;
        string description;
        uint deadline;
        bool executed;
        uint forVotes;
        uint againstVotes;
        mapping(address => bool) voted;
    }

    uint public proposalCount;
    mapping(uint => Proposal) private proposals;
    uint public quorum;

    event ProposalCreated(uint id, address to, uint amount, string description);
    event Voted(uint id, address voter, bool support);
    event Executed(uint id);

    constructor(uint _quorum) Ownable(msg.sender) {
        quorum = _quorum;
    }

    // ===== Réception ETH =====
    receive() external payable {}

    function deposit() external payable {}

    // ===== Gestion membres =====
    function addMember(address _m) external onlyOwner {
        require(!isMember[_m], "Already member");
        isMember[_m] = true;
        members.push(_m);
        emit MemberAdded(_m);
    }

    function removeMember(address _m) external onlyOwner {
        require(isMember[_m], "Not member");
        isMember[_m] = false;

        for (uint i = 0; i < members.length; i++) {
            if (members[i] == _m) {
                members[i] = members[members.length - 1];
                members.pop();
                break;
            }
        }
        emit MemberRemoved(_m);
    }

    function getMembers() external view returns (address[] memory) {
        return members;
    }

    // ===== Créer proposition =====
    function createProposal(
        address payable _to,
        uint _amount,
        string calldata _description,
        uint _duration
    ) external onlyMember {
        require(address(this).balance >= _amount, "Not enough ETH");

        proposalCount++;
        Proposal storage p = proposals[proposalCount];
        p.id = proposalCount;
        p.to = _to;
        p.amount = _amount;
        p.description = _description;
        p.deadline = block.timestamp + _duration;

        emit ProposalCreated(p.id, _to, _amount, _description);
    }

    // ===== Vote =====
    function vote(uint _id, bool support) external onlyMember {
        Proposal storage p = proposals[_id];
        require(block.timestamp < p.deadline, "Voting ended");
        require(!p.voted[msg.sender], "Already voted");

        p.voted[msg.sender] = true;
        if (support) p.forVotes++;
        else p.againstVotes++;

        emit Voted(_id, msg.sender, support);
    }

    // ===== Exécution =====
    function execute(uint _id) external nonReentrant {
        Proposal storage p = proposals[_id];
        require(!p.executed, "Already executed");
        require(block.timestamp >= p.deadline, "Too early");
        require(p.forVotes >= quorum, "Quorum not reached");
        require(p.forVotes > p.againstVotes, "Rejected");

        p.executed = true;
        (bool ok, ) = p.to.call{value: p.amount}("");
        require(ok, "Transfer failed");

        emit Executed(_id);
    }
}
