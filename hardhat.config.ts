import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import { task } from "hardhat/config";

const config: HardhatUserConfig = {
  solidity: "0.8.27",
};
export default config;

task("export-abis", "Exports the ABI of a contracts").setAction(
  async (_, hre) => {
    const fs = require("fs");
    const path = require("path");

    const contracts = ["AMBRodeoDex", "AMBRodeoTokenFactory"];

    contracts.forEach(function (contract) {
      const artifactsPath = `./artifacts/contracts/${contract}.sol/${contract}.json`;
      const artifact = JSON.parse(fs.readFileSync(artifactsPath, "utf-8"));
      const abi = artifact.abi;
      const outputPath = path.resolve(__dirname, `abis/${contract}.abi`);
      fs.mkdirSync(path.dirname(outputPath), { recursive: true });
      fs.writeFileSync(outputPath, JSON.stringify(abi, null, 2));
      console.log(`ABI exported to ${outputPath}`);
    });
  }
);
