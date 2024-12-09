import { ethers, upgrades } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  const AMBRodeo = await ethers.getContractFactory("AMBRodeo");
  let aMBRodeo = await upgrades.deployProxy(AMBRodeo, [], {
    initializer: "initialize",
  });

  console.log(`AMBRodeo: ${await aMBRodeo.getAddress()}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
