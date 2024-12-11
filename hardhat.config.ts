import { HardhatUserConfig } from "hardhat/config";
import "hardhat-tracer";
import "solidity-coverage";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import * as dotenv from "dotenv";

dotenv.config();

const privateKeyDeployer = process.env.PRIVATEKEY_DEPLOYER!;
if (!privateKeyDeployer)
  throw Error("need to set variable PRIVATEKEY_DEPLOYER");

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    dev: {
      url: "https://network.ambrosus-dev.io",
      accounts: [privateKeyDeployer],
    },
    test: {
      url: "https://network.ambrosus-test.io",
      accounts: [privateKeyDeployer],
    },
  },
};

export default config;
