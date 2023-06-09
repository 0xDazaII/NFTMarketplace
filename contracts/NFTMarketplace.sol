//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./CrazySharo.sol";

contract NFTMarketplace is ERC721URIStorage, ReentrancyGuard {
    using Counters for Counters.Counter;
    //_tokenIds variable has the most recent minted tokenId
    Counters.Counter private _tokenIds;
    //Keeps track of the number of items sold on the marketplace
    Counters.Counter private _itemsSold;
    //owner is the contract address that created the smart contract
    address payable _owner;
    //the address of the SHARO token
    CrazySharo sharoToken;
    //The fee charged by the marketplace to be allowed to list an NFT
    uint256 feePercentage = 1; //1 percent of fee

    //uint256 feePercentageVol2 = 10 * 10**18 // 10 tokens depower of 10**18

    //The structure to store info about a listed token
    struct ListedToken {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool currentlyListed;
    }

    //the event emitted when a token is successfully listed
    event TokenListedSuccess(
        uint256 indexed tokenId,
        address owner,
        address seller,
        uint256 price,
        bool currentlyListed
    );

    //Custum Errors
    error Unauthorized(address _address);
    error InsufficientAmount(uint256 _value);
    error InvalidRequest();
    error BuyerCannotBeSeller();
    error NotSalable();

    //This mapping maps tokenId to token info and is helpful when retrieving details about a tokenId
    mapping(uint256 => ListedToken) private idToListedToken;

    //Constructor
    constructor(address _sharoAddress) ERC721("NFTMarketplace", "NFTM") {
        sharoToken = CrazySharo(_sharoAddress);
        _owner = payable(msg.sender);
    }

    /* ************FUNCTIONS********************************************
     ********************************************************************
     ********************************************************************
     */
    // it updates the fee percentage OnlyOnwer
    function updateFeePercentage(uint256 _feePercentage) external payable {
        if (_owner != msg.sender) revert Unauthorized(msg.sender);

        if (_feePercentage <= 0 || _feePercentage > 10)
            revert InsufficientAmount(_feePercentage);

        feePercentage = _feePercentage;
    }

    //Gets the current feePercentage
    function getfeePercentage() public view returns (uint256) {
        return feePercentage;
    }

    //Gets listedPrice of the tokenId
    function getListPrice(uint256 tokenId) public view returns (uint256) {
        uint256 price = (idToListedToken[tokenId].price);
        uint256 listPrice = (price * feePercentage) / 100;
        return listPrice;
    }

    //Gets the latest minted TokenId
    function getLatestIdToListedToken()
        public
        view
        returns (ListedToken memory)
    {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    //Gets the address of the tokenId
    function getListedTokenForId(
        uint256 tokenId
    ) public view returns (ListedToken memory) {
        return idToListedToken[tokenId];
    }

    //Gets the current tokens
    function getCurrentToken() public view returns (uint256) {
        return _tokenIds.current();
    }

    function payTaxToOwner(uint256 tokenId) public payable {
        sharoToken.transfer(_owner, getListPrice(tokenId));
        sharoToken.allowance(address(this), msg.sender);
    }

    //The first time a token is created, it is listed here
    function createToken(
        string memory tokenURI,
        uint256 price
    ) external payable nonReentrant returns (uint) {
        //tokenAddress.transferFrom(msg.sender, address(this), price);
        //Increment the tokenId counter, which is keeping track of the number of minted NFTs
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        //Mint the NFT with tokenId newTokenId to the address who called createToken
        _safeMint(msg.sender, newTokenId);

        //Map the tokenId to the tokenURI (which is an IPFS URL with the NFT metadata)
        _setTokenURI(newTokenId, tokenURI);

        //Helper function to update Global variables and emit an event
        _createListedToken(newTokenId, price);

        return newTokenId;
    }

    //Creates token and maps it to itToListedToken
    function _createListedToken(uint256 tokenId, uint256 price) private {
        //Just sanity check
        if (price <= 0) revert InsufficientAmount(price);

        //Update the mapping of tokenId's to Token details, useful for retrieval functions
        idToListedToken[tokenId] = ListedToken(
            tokenId,
            payable(address(this)),
            payable(msg.sender),
            price,
            true
        );

        //Paying the fee to the contract owner
        sharoToken.transferFrom(msg.sender, _owner, getListPrice(tokenId));
        //payable(_owner).transfer(getListPrice(tokenId));

        _transfer(msg.sender, address(this), tokenId);
        //Emit the event for successful transfer. The frontend parses this message and updates the end user
        emit TokenListedSuccess(
            tokenId,
            address(this),
            msg.sender,
            price,
            true
        );
    }

    //This will return all the NFTs currently listed to be sold on the marketplace
    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint256 nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);
        uint256 currentIndex = 0;
        uint256 currentId;

        for (uint256 i = 0; i < nftCount; i++) {
            currentId = i + 1;
            ListedToken storage currentItem = idToListedToken[currentId];

            if (currentItem.currentlyListed) {
                tokens[currentIndex] = currentItem;
                currentIndex = currentIndex + 1;
            }
        }

        //the array 'tokens' has the list of all NFTs in the marketplace
        return tokens;
    }

    //Returns all the NFTs that the current user is owner or seller in
    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;
        uint currentId;
        //Important to get a count of all the NFTs that belong to the user before we can make an array for them
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToListedToken[i + 1].owner == msg.sender ||
                idToListedToken[i + 1].seller == msg.sender
            ) {
                itemCount += 1;
            }
        }

        //Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToListedToken[i + 1].owner == msg.sender ||
                idToListedToken[i + 1].seller == msg.sender
            ) {
                currentId = i + 1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    //The Buy Function for currently listed NFTs for sale on the marketplace
    function executeSale(
        uint256 tokenId,
        uint256 price
    ) external payable nonReentrant {
        address seller = idToListedToken[tokenId].seller;
        uint256 sellPrice = idToListedToken[tokenId].price;

        if (
            msg.sender == idToListedToken[tokenId].seller ||
            msg.sender == idToListedToken[tokenId].owner
        ) revert BuyerCannotBeSeller();

        if (!idToListedToken[tokenId].currentlyListed) revert NotSalable();

        if (price != sellPrice) revert InsufficientAmount(price);

        //update the details of the token
        idToListedToken[tokenId].currentlyListed = false;
        idToListedToken[tokenId].seller = payable(msg.sender);
        _itemsSold.increment();

        //Actually transfer the token to the new owner
        _transfer(address(this), msg.sender, tokenId);
        //approve the marketplace to sell NFTs on your behalf
        approve(address(this), tokenId);

        //Transfer the listing fee to the marketplace creator
        payTaxToOwner(tokenId);
        //(_owner).transfer(getListPrice(tokenId));

        //Transfer the proceeds from the sale to the seller of the NFT
        //uint256 proceeds = sellPrice; //- getListPrice(tokenId);

        //sharoToken.transferFrom(msg.sender, seller, proceeds);
        //sharoToken.increaseAllowance(msg.sender, 1000000);
        //sharoToken.allowance(address(this), msg.sender);
    }

    //Function for selling your NFT again on the marketplace
    function reSaleNFT(
        uint256 tokenId,
        uint256 price
    ) external payable nonReentrant {
        if (msg.sender != idToListedToken[tokenId].seller)
            revert InvalidRequest();

        //update the details of the token
        idToListedToken[tokenId].currentlyListed = true;
        idToListedToken[tokenId].price = price;

        //Transfer the listing fee to the marketplace creator
        payTaxToOwner(tokenId);
        //payable(_owner).transfer(getListPrice(tokenId));
    }

    //Function for removing your NFT for sale of the marketplace
    function cancelSale(uint256 tokenId) external {
        if (msg.sender != idToListedToken[tokenId].seller)
            revert InvalidRequest();

        //update the details of the token
        idToListedToken[tokenId].currentlyListed = false;
    }

    //Currently NFTs are listed by default
}
