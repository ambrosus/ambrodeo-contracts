import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const totalSupply = ethers.parseEther("1000");

describe("AMBRodeo", function () {
  async function dep() {
    let [owner, creator, user] = await ethers.getSigners();
    const AMBRodeo = await ethers.getContractFactory("AMBRodeo");
    let aMBRodeo = await upgrades.deployProxy(AMBRodeo, [], {
      initializer: "initialize",
    });

    await aMBRodeo.createToken([
      "TestToken1",
      "TT1",
      totalSupply,
      [1, 2, 3, 4, 5],
      "http://example.com/1.png",
    ]);
    return { aMBRodeo, owner, creator, user };
  }

  it("Should deploy the AMBRodeo contract", async function () {
    let { aMBRodeo, owner, creator, user } = await loadFixture(dep);
    expect(await aMBRodeo.getAddress()).to.properAddress;
  });

  it("Should create a new Token", async function () {
    let { aMBRodeo, owner, creator, user } = await loadFixture(dep);
    expect(await aMBRodeo.tokensCount()).to.equal(1);
  });

  it("Check new token", async function () {
    let { aMBRodeo, owner, creator, user } = await loadFixture(dep);
    const token = await ethers.getContractAt(
      "AMBRodeoToken",
      await aMBRodeo.tokensList(0)
    );

    expect(await token.balanceOf(aMBRodeo.getAddress())).to.equal(totalSupply);
    expect(await token.name()).to.equal("TestToken1");
    expect(await token.symbol()).to.equal("TT1");
    expect((await aMBRodeo.getStepPrice(token))[0]).to.equal(1);
  });

  it("Check transfer tokens", async function () {
    let { aMBRodeo, owner, creator, user } = await loadFixture(dep);
    const token = await ethers.getContractAt(
      "AMBRodeoToken",
      await aMBRodeo.tokensList(0)
    );

    await aMBRodeo.buy(token, {
      value: ethers.parseEther("1"),
    });

    expect(await token.balanceOf(owner)).to.equal(ethers.parseEther("1"));
    expect(await aMBRodeo.getBalance()).to.equal(ethers.parseEther("1"));

    await token.approve(aMBRodeo.getAddress(), ethers.parseEther("0.5"));
    await aMBRodeo.sell(token, ethers.parseEther("0.5"));

    expect(await token.balanceOf(owner)).to.equal(ethers.parseEther("0.5"));
    expect(await aMBRodeo.getBalance()).to.equal(ethers.parseEther("0.5"));
  });
});
