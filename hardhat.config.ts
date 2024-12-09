import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import * as dotenv from "dotenv";

dotenv.config();

const privateKeyDeployer = process.env.PRIVATEKEY_DEPLOYER!;
if (!privateKeyDeployer)
  throw Error("need to set variable PRIVATEKEY_DEPLOYER");

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    test: {
      url: "https://network.ambrosus-test.io",
      hardfork: "byzantium",
      accounts: [privateKeyDeployer],
    },
  },
};

export default config;
