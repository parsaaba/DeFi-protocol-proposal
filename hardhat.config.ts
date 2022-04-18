// /**
//  * @type import('hardhat/config').HardhatUserConfig
//  */
// import "tsconfig-paths/register";

// module.exports = {
//   solidity: "0.7.3",
// };

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "hardhat-gas-reporter";
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + "/.env" });

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.address);
  }
});

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      // {
      //   version: "0.8.6",
      //   settings: {
      //     optimizer: {
      //       enabled: true,
      //       runs: 200,
      //     },
      //   },
      // },
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.5.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  mocha: {
    timeout: 60000,
  },
  networks: {
    local: {
      url: `http://127.0.0.1:8545/`,
      accounts: [`0x${process.env.ACCOUNT_KEY_PRIV_LOCAL}`],
    },
    kovan: {
      url: `${process.env.NETWORK}`,
      accounts: [`0x${process.env.ACCOUNT_KEY_PRIV_KOVAN}`],
      // gas: 12000000,
      // blockGasLimit: 0x1fffffffffffff,
      // allowUnlimitedContractSize: true,
      // timeout: 1800000,
    },
  },
  gasReporter: {
    enabled: true,
    coinmarketcap: "3a70c918-991b-4402-8016-c6ba1ca65a13",
    currency: "USD",
    gasPrice: 70,
  },
};

export default config;
