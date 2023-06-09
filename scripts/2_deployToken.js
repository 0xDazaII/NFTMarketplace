const hre = require("hardhat");
const { ethers } = require("hardhat");
const NFTMarketplace = artifacts.require("NFTMarketplace");

module.exports = async function (deployer) {
  const [deployer] = await ethers.getSigners();
  const balance = await deployer.getBalance();
  const CrazySharo = await hre.ethers.getContractFactory("CrazySharo");
  const crazySharo = await CrazySharo.deploy();

  await crazySharo.deployed();

  const token = await crazySharo.deployed();

  await deployer.deploy(NFTMarketplace, token.address);
};
