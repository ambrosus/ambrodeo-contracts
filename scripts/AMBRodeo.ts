import { ethers, upgrades } from "hardhat";
import * as dotenv from "dotenv";
import { AMBRodeo } from "../typechain-types";

dotenv.config();
async function main() {
  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
  const settings: AMBRodeo.SettingsStruct = {
    maxCurvePoints: 1000,
    createToken: true,
    tokenImplemetation: ZERO_ADDRESS,
    dex: ZERO_ADDRESS,
    balanceToDex: ethers.parseEther("100"),
    createFee: ethers.parseEther("0.1"),
    exchangeFeePercent: 10000,
  };

  const contract = await ethers.getContractFactory("AMBRodeo");
  let aMBRodeo = await upgrades.deployProxy(contract, [settings], {
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
