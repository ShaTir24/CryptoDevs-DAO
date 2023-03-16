//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract FakeNFTMarketplace {
    //mapping of fake token Id to the owner addresses
    mapping(uint256 => address) public tokens;
    //setting the purchase price of each fake NFT
    uint256 nftPrice = 0.1 ether;

    //function to accept ETH and mark the owner of the as caller address
    function purchase(uint256 _tokenId) external payable {
        require(msg.value == nftPrice, "This NFT costs 0.1 ETH");
        tokens[_tokenId] = msg.sender;
    }

    //function returning price of one NFT
    function getPrice() external view returns (uint256) {
        return nftPrice;
    }

    //function to check whether he given token id is already been sold or not
    function available(uint256 _tokenId) external view returns (bool) {
        //if address associated to a tokenId in the mapping is 0x00000000000000000.. then it is unclaimed
        //address(0) = 0x000000...
        if (tokens[_tokenId] == address(0)) {
            return true;
        }
        return false;
    }
}