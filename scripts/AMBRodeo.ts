import { ethers, upgrades } from "hardhat";
import * as dotenv from "dotenv";
import { AMBRodeo } from "../typechain-types";

dotenv.config();
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const CONTRACT_ADDRESS = "0x617e07F330c7fB77af92ea9Bc957F48C17f563Ec";

async function main() {
  await upgrade();
}

async function deploy() {
  const settings: AMBRodeo.SettingsStruct = {
    createToken: true,
    tokenImplemetation: ZERO_ADDRESS,
    dex: ZERO_ADDRESS,
    balanceToDex: ethers.parseEther("1000000"),
    createFee: ethers.parseEther("10"),
    exchangeFee: 1500,
    totalSupply: ethers.parseEther("1000000000"),
    virtualLiquidity: ethers.parseEther("35000"),
    initLiquidity: false,
  };

  const contract = await ethers.getContractFactory("AMBRodeo");
  let aMBRodeo = await upgrades.deployProxy(contract, [settings], {
    initializer: "initialize",
  });
  console.log(`AMBRodeo: ${await aMBRodeo.getAddress()}`);
}

async function upgrade() {
  const contract = await ethers.getContractFactory("AMBRodeo");
  const aMBRodeo = await upgrades.upgradeProxy(CONTRACT_ADDRESS, contract);
  console.log(`AMBRodeo: ${await aMBRodeo.getAddress()}`);
}

async function getImplementation() {
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    CONTRACT_ADDRESS
  );
  console.log("Implementation address:", implementationAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
