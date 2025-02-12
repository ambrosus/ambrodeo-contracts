import { ethers, upgrades } from "hardhat";
import * as dotenv from "dotenv";
import { AMBRodeo } from "../typechain-types";

dotenv.config();
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const CONTRACT_ADDRESS = "0xe6f7bC63F52cc448AB54764Ff4F9bCBb6f48AeA7";

async function main() {
  await getImplementation();
}

async function deploy() {
  const settings: AMBRodeo.SettingsStruct = {
    createToken: true,
    tokenImplemetation: ZERO_ADDRESS,
    dex: "0xA3E524dFc9deA66aE32e81a5E2B4DF24F56e2CBc",
    balanceToDex: ethers.parseEther("1000000"),
    createFee: ethers.parseEther("1000"),
    exchangeFee: 1500,
    toDexFee: ethers.parseEther("25000"),
    totalSupply: ethers.parseEther("1000000000"),
    virtualLiquidity: ethers.parseEther("250000"),
    virtualToken: ethers.parseEther("0"),
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
