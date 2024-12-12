import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const totalSupply = ethers.parseEther("1000");
const data = ethers.hexlify(ethers.toUtf8Bytes("http://example.com/1.png"));

describe("AMBRodeo", function () {
  const TEST_STEP_PRICE = [
    ethers.parseEther("0.000000000000000001"),
    ethers.parseEther("0.000000000000000002"),
    ethers.parseEther("0.000000000000000003"),
    ethers.parseEther("0.000000000000000004"),
    ethers.parseEther("0.000000000000000005"),
  ];
  async function dep() {
    let [owner, creator, user, dex] = await ethers.getSigners();
    const AMBRodeo = await ethers.getContractFactory("AMBRodeo");
    let aMBRodeo = await upgrades.deployProxy(AMBRodeo, [], {
      initializer: "initialize",
    });

    await aMBRodeo.setDex(dex.getAddress());
    await aMBRodeo.setCreateFee(ethers.parseEther("0.1"));
    await aMBRodeo.setExchangeFee(10000);
    await aMBRodeo.setBalanceToDex(ethers.parseEther("100"));

    await aMBRodeo.createToken(
      ["TestToken1", "TT1", totalSupply, TEST_STEP_PRICE, data],
      { value: ethers.parseEther("0.1") }
    );

    const token = await ethers.getContractAt(
      "AMBRodeoToken",
      await aMBRodeo.tokensList(0)
    );

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

  it("Check settings", async function () {
    let { aMBRodeo, dex } = await loadFixture(dep);

    expect(await aMBRodeo.dex()).to.equal(await dex.getAddress());
    expect(await aMBRodeo.createFee()).to.equal(ethers.parseEther("0.1"));
    expect(await aMBRodeo.exchangeFeePercent()).to.equal(10000);
    expect(await aMBRodeo.balanceToDex()).to.equal(ethers.parseEther("100"));
  });

  it("Check new token", async function () {
    let { aMBRodeo } = await loadFixture(dep);
    const token = await ethers.getContractAt(
      "AMBRodeoToken",
      await aMBRodeo.tokensList(0)
    );

    expect(await token.name()).to.equal("TestToken1");
    expect(await token.symbol()).to.equal("TT1");
    expect(await token.totalSupply()).to.equal(ethers.parseEther("1000"));
    expect((await aMBRodeo.getStepPrice(token))[0]).to.equal(
      TEST_STEP_PRICE[0]
    );
  });

  describe("Buy and Sell", function () {
    it("Check buy tokens", async function () {
      let { aMBRodeo, token, owner } = await loadFixture(dep);
      await aMBRodeo.buy(token, {
        value: ethers.parseEther("1"),
      });

      expect(await token.balanceOf(owner)).to.equal(ethers.parseEther("0.9"));
      expect(await aMBRodeo.getBalance()).to.equal(ethers.parseEther("1.1"));
    });

    it("Check sell tokens", async function () {
      let { aMBRodeo, token, owner } = await loadFixture(dep);
      await aMBRodeo.buy(token, {
        value: ethers.parseEther("1.02"),
      });

      await token.approve(await aMBRodeo.getAddress(), ethers.parseEther("1"));
      await aMBRodeo.sell(token, await token.balanceOf(owner));

      expect(await token.balanceOf(owner)).to.equal(ethers.parseEther("0"));
      expect(await aMBRodeo.getBalance()).to.equal(ethers.parseEther("0.2938"));

      await expect(
        aMBRodeo.transferIncome(
          await owner.getAddress(),
          ethers.parseEther("0.01")
        )
      ).to.not.be.reverted;
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
      ).to.equal(ethers.parseEther("10"));

      expect(
        await aMBRodeo.calculateBuy(
          ethers.parseEther("10"),
          ethers.parseEther("10"),
          ethers.parseEther("1000"),
          TEST_STEP_PRICE
        )
      ).to.equal(ethers.parseEther("2"));

      expect(
        await aMBRodeo.calculateBuy(
          ethers.parseEther("10"),
          ethers.parseEther("400"),
          ethers.parseEther("1000"),
          TEST_STEP_PRICE
        )
      ).to.equal(ethers.parseEther("2.5"));

      await expect(
        aMBRodeo.calculateBuy(
          ethers.parseEther("10"),
          ethers.parseEther("0"),
          ethers.parseEther("1000"),
          TEST_STEP_PRICE
        )
      ).to.be.reverted;

      await expect(
        aMBRodeo.calculateBuy(
          ethers.parseEther("100"),
          ethers.parseEther("10"),
          ethers.parseEther("1000"),
          TEST_STEP_PRICE
        )
      ).to.be.reverted;
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
      ).to.equal(ethers.parseEther("10"));

      expect(
        await aMBRodeo.calculateSell(
          ethers.parseEther("10"),
          ethers.parseEther("100"),
          ethers.parseEther("1000"),
          TEST_STEP_PRICE
        )
      ).to.equal(ethers.parseEther("50"));

      expect(
        await aMBRodeo.calculateSell(
          ethers.parseEther("10"),
          ethers.parseEther("500"),
          ethers.parseEther("1000"),
          TEST_STEP_PRICE
        )
      ).to.equal(ethers.parseEther("30"));

      await expect(
        aMBRodeo.calculateSell(
          ethers.parseEther("100"),
          ethers.parseEther("950"),
          ethers.parseEther("1000"),
          TEST_STEP_PRICE
        )
      ).to.be.reverted;
    });
  });
  describe("Dex", function () {
    it("Transfer to dex and burn", async function () {
      let { aMBRodeo, token, owner, dex } = await loadFixture(dep);
      await aMBRodeo.setBalanceToDexCustom(
        token.getAddress(),
        ethers.parseEther("1")
      );
      await aMBRodeo.buy(token, {
        value: ethers.parseEther("2"),
      });

      expect(await token.balanceOf(await owner.getAddress())).to.equal(
        ethers.parseEther("1.80")
      );

      expect(await token.balanceOf(await dex.getAddress())).to.equal(
        ethers.parseEther("1.80")
      );

      expect(await ethers.provider.getBalance(await dex.getAddress())).to.equal(
        ethers.parseEther("10001.80")
      );

      expect(
        await ethers.provider.getBalance(await aMBRodeo.getAddress())
      ).to.gt(ethers.parseEther("0.11"));

      expect((await aMBRodeo.tokens(await token.getAddress())).active).to.equal(
        false
      );

      expect(
        (await aMBRodeo.tokens(await token.getAddress())).balance
      ).to.equal(0);

      expect(await token.balanceOf(await aMBRodeo.getAddress())).to.equal(
        ethers.parseEther("0")
      );
    });

    it("Transfer to dex and mint", async function () {
      let { aMBRodeo, token, owner, dex } = await loadFixture(dep);
      await aMBRodeo.setBalanceToDexCustom(
        token.getAddress(),
        ethers.parseEther("2000")
      );
      await aMBRodeo.buy(token, {
        value: ethers.parseEther("2500"),
      });

      expect(await token.balanceOf(await owner.getAddress())).to.equal(
        ethers.parseEther("850")
      );

      expect(await token.balanceOf(await dex.getAddress())).to.equal(
        ethers.parseEther("450")
      );

      expect(await ethers.provider.getBalance(await dex.getAddress())).to.equal(
        ethers.parseEther("12250")
      );

      expect(
        await ethers.provider.getBalance(await aMBRodeo.getAddress())
      ).to.gt(ethers.parseEther("0.11"));

      expect((await aMBRodeo.tokens(await token.getAddress())).active).to.equal(
        false
      );

      expect(
        (await aMBRodeo.tokens(await token.getAddress())).balance
      ).to.equal(0);

      expect(await token.balanceOf(await aMBRodeo.getAddress())).to.equal(
        ethers.parseEther("0")
      );
    });
  });

  describe("Revert", function () {
    it("Transfer income", async function () {
      let { aMBRodeo, owner } = await loadFixture(dep);
      await expect(
        aMBRodeo.transferIncome(owner.getAddress(), ethers.parseEther("1"))
      ).to.be.revertedWithCustomError(aMBRodeo, "AMBRodeo__NotEnoughIncom");
    });

    it("AmountIn must be greater than 0", async function () {
      let { aMBRodeo, token } = await loadFixture(dep);
      await expect(
        aMBRodeo.buy(token, {
          value: ethers.parseEther("0"),
        })
      ).to.be.revertedWith("AmountIn must be greater than 0");

      await expect(
        aMBRodeo.buy(token, {
          value: ethers.parseEther("0"),
        })
      ).to.be.revertedWith("AmountIn must be greater than 0");
    });

    it("Token is not active", async function () {
      let { aMBRodeo, token } = await loadFixture(dep);

      await expect(
        aMBRodeo.setBalanceToDexCustom(
          token.getAddress(),
          ethers.parseEther("10")
        )
      ).to.not.reverted;

      await expect(await aMBRodeo.deactivateToken(await token.getAddress())).to
        .not.reverted;

      await expect(
        aMBRodeo.buy(await token.getAddress(), {
          value: ethers.parseEther("11"),
        })
      ).to.be.revertedWithCustomError(aMBRodeo, "AMBRodeo__TokenNotActive");

      await expect(
        aMBRodeo.buy(await token.getAddress(), {
          value: ethers.parseEther("10"),
        })
      ).to.be.revertedWithCustomError(aMBRodeo, "AMBRodeo__TokenNotActive");

      await expect(
        aMBRodeo.buy("0x5Ff303E6E953241C3f7f6d82d7e589bCa75bFAa5", {
          value: ethers.parseEther("101"),
        })
      ).to.be.revertedWithCustomError(aMBRodeo, "AMBRodeo__TokenNotActive");

      await expect(aMBRodeo.activateToken(await token.getAddress())).to.not.be
        .reverted;
    });
    it("Step price", async function () {
      let { aMBRodeo } = await loadFixture(dep);

      await expect(
        aMBRodeo.createToken(
          [
            "TestToken1",
            "TT1",
            totalSupply,
            [
              ethers.parseEther("0.000000000000000001"),
              ethers.parseEther("0.000000000000000002"),
              ethers.parseEther("0.000000000000000001"),
            ],
            data,
          ],
          { value: ethers.parseEther("0.1") }
        )
      ).to.be.revertedWithCustomError(
        aMBRodeo,
        "AMBRodeo__InvalidTokenCreationParams"
      );
    });

    it("Name or symbol empty", async function () {
      let { aMBRodeo } = await loadFixture(dep);

      await expect(
        aMBRodeo.createToken(
          [
            "",
            "",
            totalSupply,
            [
              ethers.parseEther("0.000000000000000001"),
              ethers.parseEther("0.000000000000000002"),
              ethers.parseEther("0.000000000000000003"),
            ],
            data,
          ],
          { value: ethers.parseEther("0.1") }
        )
      ).to.be.revertedWithCustomError(
        aMBRodeo,
        "AMBRodeo__InvalidTokenCreationParams"
      );
    });
  });
});
