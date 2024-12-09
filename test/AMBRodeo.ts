import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const totalSupply = ethers.parseEther("1000");

describe("AMBRodeo", function () {
  const TEST_STEP_PRICE = [
    ethers.parseEther("1"),
    ethers.parseEther("2"),
    ethers.parseEther("3"),
    ethers.parseEther("4"),
    ethers.parseEther("5"),
  ];
  async function dep() {
    let [owner, creator, user, dex] = await ethers.getSigners();
    const AMBRodeo = await ethers.getContractFactory("AMBRodeo");
    let aMBRodeo = await upgrades.deployProxy(AMBRodeo, [], {
      initializer: "initialize",
    });

    await aMBRodeo.createToken([
      "TestToken1",
      "TT1",
      totalSupply,
      [1],
      "http://example.com/1.png",
    ]);

    const token = await ethers.getContractAt(
      "AMBRodeoToken",
      await aMBRodeo.tokensList(0)
    );

    await aMBRodeo.buy(token, {
      value: ethers.parseEther("1"),
    });
    return { aMBRodeo, token, owner, creator, user, dex };
  }

  it("Should deploy the AMBRodeo contract", async function () {
    let { aMBRodeo } = await loadFixture(dep);
    expect(await aMBRodeo.getAddress()).to.properAddress;
  });

  it("Should create a new Token", async function () {
    let { aMBRodeo } = await loadFixture(dep);
    expect(await aMBRodeo.tokensCount()).to.equal(1);
  });

  it("Check new token", async function () {
    let { aMBRodeo } = await loadFixture(dep);
    const token = await ethers.getContractAt(
      "AMBRodeoToken",
      await aMBRodeo.tokensList(0)
    );

    expect(await token.balanceOf(aMBRodeo.getAddress())).to.equal(
      totalSupply - ethers.parseEther("1")
    );
    expect(await token.name()).to.equal("TestToken1");
    expect(await token.symbol()).to.equal("TT1");
    expect((await aMBRodeo.getStepPrice(token))[0]).to.equal(1);
  });

  describe("Buy and Sell", function () {
    it("Check buy tokens", async function () {
      let { aMBRodeo, token, owner } = await loadFixture(dep);
      await aMBRodeo.buy(token, {
        value: ethers.parseEther("1"),
      });

      expect(await token.balanceOf(owner)).to.equal(ethers.parseEther("2"));
      expect(await aMBRodeo.getBalance()).to.equal(ethers.parseEther("2"));
    });

    it("Check sell tokens", async function () {
      let { aMBRodeo, token, owner } = await loadFixture(dep);

      await token.approve(aMBRodeo.getAddress(), ethers.parseEther("1"));
      await aMBRodeo.sell(token, ethers.parseEther("0.5"));

      expect(await token.balanceOf(owner)).to.equal(ethers.parseEther("0.5"));
      expect(await aMBRodeo.getBalance()).to.equal(ethers.parseEther("0.5"));
    });
  });

  describe("Calculate", function () {
    it("Buy", async function () {
      let { aMBRodeo } = await loadFixture(dep);
      expect(
        await aMBRodeo.calculateBuy(
          ethers.parseEther("10"),
          ethers.parseEther("1000"),
          ethers.parseEther("1000"),
          TEST_STEP_PRICE
        )
      ).to.equal(10);
      expect(
        await aMBRodeo.calculateBuy(
          ethers.parseEther("10"),
          ethers.parseEther("10"),
          ethers.parseEther("1000"),
          TEST_STEP_PRICE
        )
      ).to.equal(2);
      expect(
        await aMBRodeo.calculateBuy(
          ethers.parseEther("10"),
          ethers.parseEther("500"),
          ethers.parseEther("1000"),
          TEST_STEP_PRICE
        )
      ).to.equal(3);
    });

    it("Sell", async function () {
      let { aMBRodeo } = await loadFixture(dep);
      expect(
        await aMBRodeo.calculateSell(
          ethers.parseEther("10"),
          ethers.parseEther("990"),
          ethers.parseEther("1000"),
          TEST_STEP_PRICE
        )
      ).to.equal(ethers.parseEther("10000000000000000000"));
      expect(
        await aMBRodeo.calculateSell(
          ethers.parseEther("10"),
          ethers.parseEther("100"),
          ethers.parseEther("1000"),
          TEST_STEP_PRICE
        )
      ).to.equal(ethers.parseEther("50000000000000000000"));
      expect(
        await aMBRodeo.calculateSell(
          ethers.parseEther("10"),
          ethers.parseEther("500"),
          ethers.parseEther("1000"),
          TEST_STEP_PRICE
        )
      ).to.equal(ethers.parseEther("30000000000000000000"));
    });
  });
  describe("Dex", function () {
    it("Transfer to dex", async function () {
      let { aMBRodeo, token, dex } = await loadFixture(dep);
      await aMBRodeo.setDex(dex.getAddress());
      await aMBRodeo.setBalanceToDexCustom(
        token.getAddress(),
        ethers.parseEther("11")
      );
      await aMBRodeo.buy(token, {
        value: ethers.parseEther("11"),
      });
      expect(await token.balanceOf(aMBRodeo.getAddress())).to.equal(0);
      expect(await token.balanceOf(dex.getAddress())).to.equal(
        ethers.parseEther("988")
      );

      expect(await ethers.provider.getBalance(dex.getAddress())).to.equal(
        ethers.parseEther("10012")
      );
      expect(await ethers.provider.getBalance(aMBRodeo.getAddress())).to.equal(
        0
      );
      expect((await aMBRodeo.tokens(token.getAddress()))[0]).to.equal(0);
    });
  });
});
