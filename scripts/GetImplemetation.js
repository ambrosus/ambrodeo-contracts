const { upgrades } = require("hardhat");
async function main() {
  const proxyAddress = "0xA701344CF6cF7e1Fc204546B2fb79530A4198B52";
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    proxyAddress
  );

  console.log("Implementation address:", implementationAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
