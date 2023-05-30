require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("dotenv").config();
const fs = require("fs");
// const infuraId = fs.readFileSync(".infuraid").toString().trim() || "";

const { REACT_APP_ALCHEMY_SEPOLIA_API_KEY, REACT_APP_SEPOLIA_PRIVATE_KEY } =
  process.env;

/*task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});*/

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 1337,
    },
    sepolia: {
      url: REACT_APP_ALCHEMY_SEPOLIA_API_KEY,
      accounts: [REACT_APP_SEPOLIA_PRIVATE_KEY],
    },
    goerli: {
      url: process.env.REACT_APP_ALCHEMY_API_URL,
      accounts: [process.env.REACT_APP_PRIVATE_KEY],
    },
  },
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
};
