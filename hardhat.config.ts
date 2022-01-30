import '@typechain/hardhat'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import "@nomiclabs/hardhat-etherscan"
import { HardhatUserConfig } from "hardhat/types";
import { privateKey } from './settings.json'

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ],
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      },
      allowUnlimitedContractSize: false,
    },
    ropsten: {
      chainId: 3,
      url: "https://ropsten.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
      gasMultiplier: 1.25,
      accounts: [privateKey]
    },
    bsctest: {
      chainId: 97,
      url: "https://data-seed-prebsc-2-s3.binance.org:8545/",
      gasMultiplier: 1.25,
      accounts: [privateKey]
    },
    bscmain: {
      chainId: 56,
      url: "https://bsc-dataseed.binance.org",
      gasMultiplier: 1.25,
      accounts: [privateKey]
    }
  },
  mocha: {
    timeout: 200000
  }
};
export default config;