import { ethers, upgrades } from "hardhat";
import * as dotenv from "dotenv";
import { AMBRodeo, AMBRodeoToken } from "../typechain-types";

dotenv.config();
const CONTRACT_ADDRESS = "0x833Ae768cC7568c567983E05671d2d528609B862";
const TOKENS = 1;
const TRADE = 5;
const data = ethers.hexlify(ethers.toUtf8Bytes(""));

async function main() {
  for (let i = 0; i < TOKENS; i++) {
    const contract: AMBRodeo = await ethers.getContractAt(
      "AMBRodeo",
      CONTRACT_ADDRESS
    );
    const tx = await contract.createToken(
      0,
      getRandomString(10),
      getRandomString(3),
      data,
      {
        value: ethers.parseEther("17"),
      }
    );
    await tx.wait();
    console.log("Tx: ", tx.hash);
    const receipt = await ethers.provider.getTransactionReceipt(tx.hash);
    if (receipt && receipt.logs.length > 0) {
      const decodedEvents = receipt.logs
        .map((log) => {
          try {
            const decodedLog = contract.interface.parseLog(log);
            if (decodedLog?.name === "CreateToken") {
              return decodedLog.args;
            }
          } catch (e) {
            console.log(e);
            return null;
          }
        })
        .filter((event) => event !== null);
      if (decodedEvents.length > 0) {
        const event = decodedEvents[2];
        const tokenAddress = event?.token;
        const token: AMBRodeoToken = await ethers.getContractAt(
          "AMBRodeoToken",
          tokenAddress
        );
        await trade(contract, token);
      }
    }
  }
}

async function trade(contract: AMBRodeo, token: AMBRodeoToken) {
  const [key] = await ethers.getSigners();
  for (let i = 0; i < TRADE; i++) {
    let random = Math.floor(Math.random() * 10) + 1;
    const amount = (await token.balanceOf(key.address)) / BigInt(random);
    const tx_approve = await token.approve(await contract.getAddress(), amount);
    await tx_approve.wait();
    console.log(amount);
    const tx_sell = await contract.sell(await token.getAddress(), amount);
    await tx_sell.wait();
    random = Math.floor(Math.random() * 100) + 1;
    await contract.buy(await token.getAddress(), {
      value: ethers.parseEther(random.toString()),
    });
  }
}

function getRandomString(length: number): string {
  const chars =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let result = "";
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
