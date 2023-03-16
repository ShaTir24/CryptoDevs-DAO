//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IFakeNFTMarketplace {
    function getPrice() external view returns (uint256);
    //returns the price of an NFT from the FakeNFTMarketplace

    function available(uint256 _tokenId) external view returns(bool);
    //returns whether the given tokenId has already been purchased or not

    function purchase(uint256 _tokenId) external payable;
    //function to purchase fake NFT TokenId to purchase
}

interface ICryptoDevsNFT {
    function balanceOf(address owner) external view returns(uint256);
    //returns the number of NFTs owned by the given address params

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns(uint256);
    //returns a tokenId at given index for owner
}

contract CryptoDevsDAO is Ownable {
    struct Proposal {
        uint256 nftTokenId;    //tokenID of the NFT to purchase from fakeNFTmarketplace if the proposal passes
        uint256 deadline;   //the UNIX timestamp untill which this proposal is active. It can be executed after deadline have been exceeded
        uint256 yayVotes;   //no. of votes in favour of this proposal
        uint256 nayVotes;   //no. of votes against the proposal
        bool executed;  //whether this proposal is executed or not
        mapping(uint256 => bool) voters;    //whether an NFT has been already used to cast a vote or not
    }

    //proposalID to proposal to hold all created proposals
    mapping(uint256 => Proposal) public proposals;
    //total number of proposals created
    uint256 public numProposals;

    //creating an instance of contracts on which we are going to call the functions
    IFakeNFTMarketplace nftMarketplace;
    ICryptoDevsNFT cryptoDevsNFT;

    //creating a payable constructor to:
    //initialize contract variables
    //accept the ETH deposit from the deployer or owner to fill the DAO treasury (payable)
    constructor(address _nftMarketPlace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nftMarketPlace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    //only allowing the function to be called by someone who owns at least 1 NFT
    modifier nftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT_A_MEMBER_OF_DAO");
        _;
    }

    //function to create new proposals
    //allow only NFT holders to create proposal
    //_nftTokenId - the tokenID of the NFT to be purchased from FakeNFTMarketplace if this proposal passes
    //returns the proposal Id of newly created proposal
    function createProposal(uint256 _nftTokenId) external nftHolderOnly returns(uint256) {
        require(nftMarketplace.available(_nftTokenId), "NFT_NOT_FOR_SALE");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;
        //setting the proposal's voting deadline to be current time + 5mins
        proposal.deadline = block.timestamp + 5 minutes;
        numProposals++;
        return numProposals - 1;
    }

    //condition to vote on a proposal only if dealine is not exceeded
    modifier activeProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline > block.timestamp,
            "DEADLINE_EXCEEDED"
        );
        _;
    }

    //enum representing possible options of vote
    enum Vote {
        YAY,     //YAY = 0
        NAY     //NAY = 0
    }

    //function to cast the NFT holder to vote on the active proposal
    function voteOnProposal(uint256 proposalIndex, Vote vote) external nftHolderOnly activeProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];
        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        //compute how many NFTs are owned by the voter that has not been used for voting on this proposal
        for(uint256 i = 0; i < voterNFTBalance; i++) {
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if(proposal.voters[tokenId] == false) {
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }
        require(numVotes > 0, "ALREADY_VOTED");
        if(vote == Vote.YAY) {
            proposal.yayVotes += numVotes;
        } else {
            proposal.nayVotes += numVotes;
        }
    }

    //condition to call a function if the given proposal deadline has been exceeded and if the proposal has not yet been executed
    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline <= block.timestamp, "DEADLINE_NOT_EXCEEDED"
        );
        require(
            proposals[proposalIndex].executed == false, "PROPOSAL_ALREADY_EXECUTED"
        );
        _;
    }

    //function to allow any NFT holder to execute the proposal after the deadline has been exceeded
    function executeProposal(uint256 proposalIndex) external nftHolderOnly inactiveProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];

        //purchase the NFT if major votes are YAY
        if(proposal.yayVotes > proposal.nayVotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }

    //function to allow the contract owner to deposit the ETH from contract to his wallet account
    function withdrawEther() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "Nothing to withdraw, contract balance empty!");
        (bool sent, ) = payable(owner()).call{value: amount}("");
        require(sent, "FAILED_TO_WITHDRAW_EHTER");
    }

    //to allow the contract to accept ETH deposits directly from a wallet without calling a function
    receive() external payable {}
    fallback() external payable {}
}