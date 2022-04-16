import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";

import "@nomiclabs/hardhat-ethers";
import "hardhat-diamond-abi";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";

dotenv.config();

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const config: HardhatUserConfig = {
  solidity: "0.8.10",
  networks: {
    localhost: {},
    hardhat: {
      forking: {
        url: "https://mainnet.aurora.dev",
      },
      accounts: [
        {
          privateKey: String(process.env.MAINNET_PRIV_KEY),
          balance: (100e18).toString(),
        },
      ],
    },
    auroraTestnet: {
      url: "https://testnet.aurora.dev",
      accounts: [String(process.env.TESTNET_PRIV_KEY)],
    },
    auroraMainnet: {
      url: "https://mainnet.aurora.dev",
      accounts: [String(process.env.MAINNET_PRIV_KEY)],
      timeout: 600000,
    },
  },
  diamondAbi: {
    name: "ERC721Diamond",
    include: [
      "AccessControlFacet",
      "ERC721URIStorage",
      "RentalFacet",
      "UnderlyingCurrencyFacet",
      "WithdrawalFacet",
      "DiamondLoupeFacet",
      "DiamondCutFacet",
      "OwnershipFacet",
    ],
  },
  paths: {
    sources: "contracts",
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
};

export default config;
