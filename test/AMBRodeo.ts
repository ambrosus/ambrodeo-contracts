import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { AMBRodeo } from "../typechain-types";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const TEST_STEP_PRICE = [
  ethers.parseEther("0.000000000000000001"),
  ethers.parseEther("0.000000000000000002"),
  ethers.parseEther("0.000000000000000003"),
  ethers.parseEther("0.000000000000000004"),
  ethers.parseEther("0.000000000000000005"),
  ethers.parseEther("0.000000000000000006"),
  ethers.parseEther("0.000000000000000007"),
  ethers.parseEther("0.000000000000000008"),
  ethers.parseEther("0.000000000000000009"),
  ethers.parseEther("0.000000000000000010"),
];
const DATA = ethers.hexlify(ethers.toUtf8Bytes("http://example.com/1.png"));

describe("AMBRodeo", function () {
  async function dep() {
    let [owner, creator, user, dex] = await ethers.getSigners();
    const settings: AMBRodeo.SettingsStruct = {
      maxCurvePoints: 1000,
      createToken: true,
      tokenImplemetation: ZERO_ADDRESS,
      dex: await dex.getAddress(),
      balanceToDex: ethers.parseEther("50"),
      createFee: ethers.parseEther("0.1"),
      exchangeFeePercent: 10000,
    };

    const tokenParams: AMBRodeo.CreateTokenParamsStruct = {
      name: "TestToken1",
      symbol: "TT1",
      maxSupply: ethers.parseEther("1000"),
      royaltyPercent: 10000,
      curvePoints: TEST_STEP_PRICE,
      data: DATA,
    };

    const contract = await ethers.getContractFactory("AMBRodeo");
    let aMBRodeo = await upgrades.deployProxy(contract, [settings], {
      initializer: "initialize",
    });

    await aMBRodeo.createToken(tokenParams, {
      value: ethers.parseEther("0.1"),
    });

    const token = await ethers.getContractAt(
      "AMBRodeoToken",
      await aMBRodeo.list(0)
    );
    return { aMBRodeo, token, owner, creator, user, dex };
  }

  describe("Check deploy", function () {
    it("Should deploy the AMBRodeo contract", async function () {
      const { aMBRodeo } = await loadFixture(dep);
      expect(await aMBRodeo.getAddress()).to.properAddress;
    });

    it("Should create a new Token", async function () {
      const { aMBRodeo } = await loadFixture(dep);
      expect(await aMBRodeo.tokensCount()).to.equal(1);
    });

    it("Check settings", async function () {
      const { aMBRodeo, dex } = await loadFixture(dep);
      const settings = await aMBRodeo.settings();
      expect(await settings.dex).to.equal(await dex.getAddress());
      expect(await settings.createFee).to.equal(ethers.parseEther("0.1"));
      expect(await settings.exchangeFeePercent).to.equal(10000);
      expect(await settings.balanceToDex).to.equal(ethers.parseEther("50"));
    });

    it("Check new token", async function () {
      let { aMBRodeo, token } = await loadFixture(dep);
      const t = await aMBRodeo.tokens(await token.getAddress());
      expect(await t.maxSupply).to.equal(ethers.parseEther("1000"));
      expect(await t.royaltyLock).to.equal(true);
    });

    it("Check creator presale", async function () {
      let { aMBRodeo, token, owner } = await loadFixture(dep);
      const tokenParams: AMBRodeo.CreateTokenParamsStruct = {
        name: "TestToken2",
        symbol: "TT2",
        maxSupply: ethers.parseEther("1000"),
        royaltyPercent: 10000,
        curvePoints: TEST_STEP_PRICE,
        data: DATA,
      };

      await aMBRodeo.createToken(tokenParams, {
        value: ethers.parseEther("2.1"),
      });
      const token2 = await ethers.getContractAt(
        "AMBRodeoToken",
        await aMBRodeo.list(1)
      );
      expect(await token2.balanceOf(await owner.getAddress())).to.equal(
        ethers.parseEther("2")
      );
    });
  });

  describe("Mint, Burn, Swap", function () {
    it("Check mint tokens", async function () {
      let { aMBRodeo, token, user } = await loadFixture(dep);
      await aMBRodeo.connect(user).mint(token, {
        value: ethers.parseEther("1"),
      });

      expect(await aMBRodeo.internalBalance()).to.equal(
        ethers.parseEther("0.2")
      );
      expect(await aMBRodeo.getBalance()).to.equal(ethers.parseEther("1.1"));
      expect(await token.balanceOf(await user.getAddress())).to.equal(
        ethers.parseEther("0.81")
      );
      const t = await aMBRodeo.tokens(await token.getAddress());
      expect(t.balance).to.equal(ethers.parseEther("0.81"));
      expect(t.royalty).to.equal(ethers.parseEther("0.09"));
    });

    it("Check burn tokens", async function () {
      let { aMBRodeo, token, user } = await loadFixture(dep);
      await aMBRodeo.connect(user).mint(token, {
        value: ethers.parseEther("2"),
      });
      await aMBRodeo.connect(user).burn(token, ethers.parseEther("1"));

      expect(await aMBRodeo.internalBalance()).to.equal(
        ethers.parseEther("0.4")
      );
      expect(await aMBRodeo.getBalance()).to.equal(ethers.parseEther("1.29"));
      expect(await token.balanceOf(await user.getAddress())).to.equal(
        ethers.parseEther("0.62")
      );
      const t = await aMBRodeo.tokens(await token.getAddress());
      expect(t.balance).to.equal(ethers.parseEther("0.62"));
      expect(t.royalty).to.equal(ethers.parseEther("0.27"));
    });

    it("Check swap tokens", async function () {
      let { aMBRodeo, token, user } = await loadFixture(dep);
      await aMBRodeo.connect(user).mint(token, {
        value: ethers.parseEther("2"),
      });
      const tokenParams: AMBRodeo.CreateTokenParamsStruct = {
        name: "TestToken2",
        symbol: "TT2",
        maxSupply: ethers.parseEther("1000"),
        royaltyPercent: 10000,
        curvePoints: TEST_STEP_PRICE,
        data: DATA,
      };

      await aMBRodeo.createToken(tokenParams, {
        value: ethers.parseEther("0.1"),
      });
      const token2 = await ethers.getContractAt(
        "AMBRodeoToken",
        await aMBRodeo.list(1)
      );

      await aMBRodeo
        .connect(user)
        .swap(
          await token.getAddress(),
          await token2.getAddress(),
          ethers.parseEther("1")
        );

      expect(await token.balanceOf(await user.getAddress())).to.equal(
        ethers.parseEther("0.62")
      );
      expect(await token2.balanceOf(await user.getAddress())).to.equal(
        ethers.parseEther("0.729")
      );

      const t = await aMBRodeo.tokens(await token.getAddress());
      expect(t.balance).to.equal(ethers.parseEther("0.62"));
      expect(t.royalty).to.equal(ethers.parseEther("0.27"));

      const t2 = await aMBRodeo.tokens(await token2.getAddress());
      expect(t2.balance).to.equal(ethers.parseEther("0.729"));
      expect(t2.royalty).to.equal(ethers.parseEther("0.081"));

      expect(await aMBRodeo.internalBalance()).to.equal(
        ethers.parseEther("0.5")
      );
    });
  });
  describe("Dex", function () {
    it("Check transfer to dex", async function () {
      let { aMBRodeo, token, user, dex } = await loadFixture(dep);
      await aMBRodeo.connect(user).mint(token, {
        value: ethers.parseEther("70"),
      });
      expect(await token.balanceOf(await dex.getAddress())).to.equal(
        ethers.parseEther("56.7")
      );
      expect(await ethers.provider.getBalance(await dex.getAddress())).to.equal(
        ethers.parseEther("10056.7")
      );
      expect(await aMBRodeo.getBalance())
        .gt(ethers.parseEther("13"))
        .and.lt(ethers.parseEther("13.5"));

      const t = await aMBRodeo.tokens(await token.getAddress());
      expect(t.balance).to.equal(ethers.parseEther("0"));
      expect(t.royalty).to.equal(ethers.parseEther("6.3"));
      expect(t.royaltyLock).to.equal(false);
      expect(t.active).to.equal(false);
      expect(await aMBRodeo.internalBalance())
        .gt(ethers.parseEther("7"))
        .lt(ethers.parseEther("7.1"));
    });
    it("Check transfer royalty", async function () {
      let { aMBRodeo, token, user, dex } = await loadFixture(dep);
      await aMBRodeo.connect(user).mint(token, {
        value: ethers.parseEther("70"),
      });

      expect(
        await aMBRodeo.transferRoyalty(
          await token.getAddress(),
          ethers.parseEther("6.3")
        )
      ).not.reverted;
      const t = await aMBRodeo.tokens(await token.getAddress());
      expect(t.royalty).to.equal(ethers.parseEther("0"));
    });
  });
  describe("Calculate", function () {
    it("Max mint and burn", async function () {
      let { aMBRodeo, token, owner } = await loadFixture(dep);

      const tokenParams: AMBRodeo.CreateTokenParamsStruct = {
        name: "TestToken2",
        symbol: "TT2",
        maxSupply: ethers.parseEther("5"),
        royaltyPercent: 10000,
        curvePoints: TEST_STEP_PRICE,
        data: DATA,
      };

      await aMBRodeo.createToken(tokenParams, {
        value: ethers.parseEther("0.1"),
      });
      const token2 = await ethers.getContractAt(
        "AMBRodeoToken",
        await aMBRodeo.list(1)
      );

      await aMBRodeo.mint(await token2.getAddress(), {
        value: ethers.parseEther("33"),
      });

      await expect(
        aMBRodeo.mint(await token2.getAddress(), {
          value: ethers.parseEther("1"),
        })
      ).to.be.reverted;

      await aMBRodeo.burn(
        await token2.getAddress(),
        await token2.balanceOf(await owner.getAddress())
      );
      expect(await token2.balanceOf(await owner.getAddress())).to.equal(0);
    });
  });
});
