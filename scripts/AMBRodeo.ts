import { ethers, upgrades } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  const totalSupply = process.env.AMBRODEO_TOKEN_TOTALSUPPLY;
  if (!totalSupply)
    throw Error("need to set variable AMBRODEO_TOKEN_TOTALSUPPLY");

  const initLiquidity = process.env.AMBRODEO_INIT_LIQUIDITY;
  if (!initLiquidity)
    throw Error("need to set variable AMBRODEO_INIT_LIQUIDITY");

  const dexFee = process.env.AMBRODEO_DEX_FEE;
  if (!dexFee) throw Error("need to set variable AMBRODEO_DEX_FEE");

  const fectoryFee = process.env.AMBRODEO_FACTORY_FEE;
  if (!totalSupply) throw Error("need to set variable AMBRODEO_FACTORY_FEE");

  const AMBRodeoDex = await ethers.getContractFactory("AMBRodeoDex");
  let dex = await upgrades.deployProxy(AMBRodeoDex, [initLiquidity, dexFee], {
    initializer: "initialize",
  });

  const AMBRodeoTokenFactory = await ethers.getContractFactory(
    "AMBRodeoTokenFactory"
  );
  let tokenFactory = await upgrades.deployProxy(
    AMBRodeoTokenFactory,
    [await dex.getAddress(), ethers.parseEther(totalSupply), fectoryFee],
    {
      initializer: "initialize",
    }
  );

  await dex.setFactory(tokenFactory.getAddress());

  console.log(`AMBRodeoTokenFactory: ${await tokenFactory.getAddress()}`);
  console.log(`AMBRodeoDex: ${await dex.getAddress()}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
