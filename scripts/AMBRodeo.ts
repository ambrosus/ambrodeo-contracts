import { ethers, upgrades } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  const AMBRodeo = await ethers.getContractFactory("AMBRodeo");
  let aMBRodeo = await upgrades.deployProxy(AMBRodeo, [], {
    initializer: "initialize",
  });
  // const aMBRodeo = await upgrades.upgradeProxy(
  //   "0xA701344CF6cF7e1Fc204546B2fb79530A4198B52",
  //   AMBRodeo
  // );
  console.log(`AMBRodeo: ${await aMBRodeo.getAddress()}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
