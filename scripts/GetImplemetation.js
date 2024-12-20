const { upgrades } = require("hardhat");
async function main() {
  const proxyAddress = "0x1831312B959f0aa66Abb1504125ab9dE9c33aA31";
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    proxyAddress
  );

  console.log("Implementation address:", implementationAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
