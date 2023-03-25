import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import { HardhatUserConfig } from "hardhat/config";
import "hardhat-deploy";
import "@nomiclabs/hardhat-etherscan";

import "solidity-coverage";

import * as fs from "fs";

// const mnemonicFileName = process.env.MNEMONIC_FILE ?? `${process.env.HOME}/.secret/testnet-mnemonic.txt`
// let mnemonic = 'test '.repeat(11) + 'junk'
// if (fs.existsSync(mnemonicFileName)) { mnemonic = fs.readFileSync(mnemonicFileName, 'ascii') }
let account = [
  "92731ae580575e44f5e6532a8b926f081181b1fa4c8976748988ffa5de7f2570",
];
function getNetwork1(url: string): { url: string; accounts: string[] } {
  return {
    url,
    accounts: [
      "92731ae580575e44f5e6532a8b926f081181b1fa4c8976748988ffa5de7f2570",
    ],
  };
}

function getNetwork(name: string): { url: string; accounts: string[] } {
  return getNetwork1(`https://${name}.infura.io/v3/f1bed5a8674b48cdad93d8f6c69e7201`);
}

const optimizedComilerSettings = {
  version: "0.8.17",
  settings: {
    optimizer: { enabled: true, runs: 1000000 },
    viaIR: true,
  },
};

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.15",
        settings: {
          optimizer: { enabled: true, runs: 1000000 },
        },
      },
    ],
    overrides: {
      "contracts/core/EntryPoint.sol": optimizedComilerSettings,
      "contracts/samples/SimpleAccount.sol": optimizedComilerSettings,
    },
  },
  networks: {
    dev: { url: "http://localhost:8545" },
    // github action starts localgeth service, for gas calculations
    localgeth: { url: "http://localgeth:8545" },
    goerli: getNetwork("goerli"),
    sepolia: getNetwork("sepolia"),
    proxy: getNetwork1("http://localhost:8545"),
  },
  mocha: {
    timeout: 10000,
  },

  etherscan: {
    apiKey: "E875E9XHFVBD2YCBSBTZPE72Q1156U8PEQ",
  },
};

// coverage chokes on the "compilers" settings
if (process.env.COVERAGE != null) {
  // @ts-ignore
  config.solidity = config.solidity.compilers[0];
}

export default config;
