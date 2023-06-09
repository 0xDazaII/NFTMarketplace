const { expectRevert, expectEvent, BN } = require("@openzeppelin/test-helpers");
const assert = require("assert");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTMarketplace", function () {
  let NFTMarketplace,
    NFTMarketplaceContract,
    owner,
    addr1,
    addr2,
    SharoToken,
    SharoContract;

  beforeEach(async function () {
    SharoToken = await ethers.getContractFactory("CrazySharo");
    SharoContract = await SharoToken.deploy();
    NFTMarketplace = await ethers.getContractFactory("NFTMarketplace");
    [owner, addr1, addr2] = await ethers.getSigners();
    NFTMarketplaceContract = await NFTMarketplace.deploy(SharoContract.address);
  });

  describe("updateFeePercentage", function () {
    it("Should be reverted because the caller is not owner", async function () {
      await expect(
        NFTMarketplaceContract.connect(addr1).updateFeePercentage(3)
      ).to.be.revertedWith("Unauthorized");
    });

    it("Should change the feePercentage by owner", async function () {
      const expectedValue = 3;
      await NFTMarketplaceContract.connect(owner).updateFeePercentage(
        expectedValue
      );

      expect(await NFTMarketplaceContract.getfeePercentage()).to.equal(
        expectedValue
      );
    });
  });

  describe("createToken", function () {
    it("Should mint and list token for sale", async function () {
      const baseURI = "ipfs://test.url/";
      const price = 97;
      await NFTMarketplaceContract.connect(addr1).createToken(baseURI, price);

      expect(await NFTMarketplaceContract.tokenURI(1)).to.equal(baseURI); //ipfs://test.url/
      expect(await NFTMarketplaceContract.ownerOf(1)).to.equal(
        NFTMarketplaceContract.address
      );
    });

    it("Should not mint the token if price is negative or zero", async function () {
      const baseURI = "ipfs://test.url/";
      const price = 0;

      await expect(
        NFTMarketplaceContract.connect(addr1).createToken(baseURI, price)
      ).to.be.revertedWith("InsufficientAmount");
    });
  });
  describe("getAllNFTs", function () {
    it("Should return all NFTs in the marketplace", async function () {
      const baseURI = "ipfs://test.url/";
      const price = 1;
      await NFTMarketplaceContract.connect(addr1).createToken(baseURI, price);

      return expect(NFTMarketplaceContract.getAllNFTs());
    });
  });

  describe("getMyNFTs", function () {
    it("Should return all the NFTs that the current user is owner or seller in", async function () {
      const baseURI = "ipfs://test.url/";
      const price = 1;
      await NFTMarketplaceContract.connect(addr1).createToken(baseURI, price);

      return expect(NFTMarketplaceContract.getMyNFTs());
    });
  });

  describe("executeSale", function () {
    it("Should prevent sale - buyer cannot buy his own NFT", async function () {
      const baseURI = "ipfs://test.url/";
      const price = 1;
      const payPrice = 1;
      await NFTMarketplaceContract.connect(addr1).createToken(baseURI, price);
      await expect(
        NFTMarketplaceContract.connect(addr1).executeSale(1, payPrice)
      ).to.be.revertedWith("BuyerCannotBeSeller");
    });

    it("Should prevent sale - insufficient payment", async function () {
      const baseURI = "ipfs://test.url/";
      const price = 2;
      const tokenId = 1;
      const amount = 1;
      await NFTMarketplaceContract.connect(addr1).createToken(baseURI, price);

      await expect(
        NFTMarketplaceContract.connect(addr2).executeSale(tokenId, amount)
      ).to.be.revertedWith("InsufficientAmount");
    });

    it("Should execute sale successful", async function () {
      const baseURI = "ipfs://test.url/";
      const price = 10;
      const tokenId = 1;
      const amount = 10;
      const listPrice = await NFTMarketplaceContract.getListPrice(tokenId);
      const ownerBalanceBefore = await NFTMarketplaceContract.balanceOf(
        owner.address
      );
      const ownerBalanceAfter = ownerBalanceBefore + listPrice;
      await NFTMarketplaceContract.connect(addr1).createToken(baseURI, price);
      expect(
        await NFTMarketplaceContract.connect(addr2).executeSale(tokenId, amount)
      );
      expect(await NFTMarketplaceContract.balanceOf(owner.address)).to.equal(
        ownerBalanceAfter
      );
    });
  });

  describe("reSale", function () {
    it("Should revert if sender is not the owner of the NFT", async function () {
      const baseURI = "ipfs://test.url/";
      const price = 10;
      const tokenId = 1;
      const amount = 10;
      const newPrice = 15;

      await NFTMarketplaceContract.connect(addr1).createToken(baseURI, price);
      await NFTMarketplaceContract.connect(addr2).executeSale(tokenId, amount);
      await expect(
        NFTMarketplaceContract.connect(addr1).reSaleNFT(tokenId, newPrice)
      ).to.be.revertedWith("InvalidRequest");
    });

    it("Should sell the nft and transfer the taxFee to the contract owner", async function () {
      const baseURI = "ipfs://test.url/";
      const price = 10;
      const tokenId = 1;
      const amount = 10;
      const newPrice = 15;

      /*const currlisted = await NFTMarketplaceContract.getListedTokenForId(
        tokenId
      ).currentlyListed;
      const updatedPrice = await NFTMarketplaceContract.getListedTokenForId(
        tokenId
      ).price; */

      await NFTMarketplaceContract.connect(addr1).createToken(baseURI, price);
      await NFTMarketplaceContract.connect(addr2).executeSale(tokenId, amount);
      expect(
        await NFTMarketplaceContract.connect(addr2).reSaleNFT(tokenId, newPrice)
      );
      expect(
        await NFTMarketplaceContract.connect(addr2).payTaxToOwner(tokenId)
      );
      //expect(await NFTMarketplaceContract.getListedTokenForId(tokenId).currentlyListed).to.be.true();
      //expect(await NFTMarketplaceContract.updatedPrice).to.equal(newPrice);
    });
  });

  describe("cancleSale", function () {
    it("Should rever if sender is not the owner", async function () {
      const baseURI = "ipfs://test.url/";
      const price = 10;
      const tokenId = 1;

      await NFTMarketplaceContract.connect(addr1).createToken(baseURI, price);

      await expect(
        NFTMarketplaceContract.connect(addr2).cancelSale(tokenId)
      ).to.be.revertedWith("InvalidRequest");
    });

    it("Should cancle the sale of the selected NFT", async function () {
      const baseURI = "ipfs://test.url/";
      const price = 10;
      const tokenId = 1;

      await NFTMarketplaceContract.connect(addr1).createToken(baseURI, price);
      expect(await NFTMarketplaceContract.connect(addr1).cancelSale(tokenId));
    });
  });
});
