const { upgrades } = require("hardhat");
async function main() {
  const proxyAddress = "0x617e07F330c7fB77af92ea9Bc957F48C17f563Ec";
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    proxyAddress
  );

  console.log("Implementation address:", implementationAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
