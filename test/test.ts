import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect, use } from "chai";
import { ethers } from "hardhat";
import { parseEther } from "ethers/lib/utils";

// import { ethers } from "hardhat";
// import { expect } from "chai";
async function _advanceBlock() {
  return ethers.provider.send("evm_mine", []);
}

async function advanceBlock(blockNumber: number) {
  for (let i = await ethers.provider.getBlockNumber(); i < blockNumber; i++) {
    await _advanceBlock();
  }
}

async function advanceBlockTo(blockNumber: number) {
  let currentBlock = await ethers.provider.getBlockNumber();
  let moveTo = currentBlock + blockNumber;
  //console.log("From: ", currentBlock.toString(), "To: ", moveTo.toString());
  await advanceBlock(moveTo);
}
async function deployZAP() {
  const ZAP = await ethers.getContractFactory("Zap");
  const zap = await ZAP.deploy();
  return { zap };
}

async function deploySWap() {
  const Swap = await ethers.getContractFactory("TestSwap");
  const swap = await Swap.deploy();
  return { swap };
}

async function deploy_CAKE_ETH_Vault() {
  let name = "A";
  let sysmbol = "B";
  let tickLower = "-887272";
  let tickUpper = "887272";
  let pool = "0x133B3D95bAD5405d14d53473671200e9342896BF"
  const [user0] = await ethers.getSigners();
  const SwapLib = await ethers.getContractFactory("Swap");
  const swaplib = await SwapLib.deploy();
  //let a = await swaplib.getAddress();
  const LiquidityLib = await ethers.getContractFactory("Liquidity");
  const liquiditylib = await LiquidityLib.deploy();
  //let b = await liquiditylib.getAddress();
  const VAULT = await ethers.getContractFactory("Vault",{
    // libraries:{
    //   Swap:swaplib.address,
    //   //Liquidity:b,
      
    // },
  });
  const vault = await VAULT.deploy(
    name,
    sysmbol,
    pool,
  );
  let token1 = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";//WBNB
  let token0 = "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82";//cake
  let router = "0x13f4EA83D0bd40E75C8222255bc855a974568Dd4";
  const ERC20 = await ethers.getContractFactory("TESTERC20");
  const lp0 = await ERC20.attach("0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82");
  const lp1 = await ERC20.attach("0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c");

  return { vault,token0,token1,lp0,lp1,router};
}



  describe("ZAP and VAULT", function () {
    it("test Vault",async () => {
      const [user0,user1] = await ethers.getSigners();
      const {swap} =  await loadFixture(deploySWap);
      const { vault,token0,token1,lp0,lp1,router } = await loadFixture(deploy_CAKE_ETH_Vault);
      await swap.singleSwap(token1,token0,parseEther("10"),1,"2500",router,{value: parseEther("10")});
      await lp0.approve(vault.address,parseEther("100000000"));
      let x = await vault.initializeVault(parseEther("100"),parseEther("100"),parseEther("0.1"),parseEther("0.1"),{value:parseEther("100")});
      //await vault.zapOut(vault.balanceOf(user0.address),0,0,user0.address);
      await vault.connect(user1).zapInSingle(token1,parseEther("1"),0,{value:parseEther("1")});
      await vault.zapInDual(lp0.balanceOf(user0.address),parseEther("1"),0,0,{value:parseEther("1")});
      await vault.zapOut(vault.balanceOf(user0.address),0,0);
      await vault.connect(user1).zapOutAndSwap(vault.balanceOf(user1.address),0,0,token1,0);
      //await vault.pauseAndWithdrawNFT();
      //console.log(x)
      //await vault.initializeVault(0,0,0,0);
      // vault.s
      //await lock.zapIn("0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c","0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82",2500,-58800,-44300, parseEther("1"),0,{value:parseEther("1")});
    })
    // it("Should set the right unlockTime", async function () {
    //   const { lock, unlockTime } = await loadFixture(deployOneYearLockFixture);

    //   expect(await lock.unlockTime()).to.equal(unlockTime);
    // });

    // it("Should set the right owner", async function () {
    //   const { lock, owner } = await loadFixture(deployOneYearLockFixture);

    //   expect(await lock.owner()).to.equal(owner.address);
    // });

    // it("Should receive and store the funds to lock", async function () {
    //   const { lock, lockedAmount } = await loadFixture(
    //     deployOneYearLockFixture
    //   );

    //   expect(await ethers.provider.getBalance(lock.target)).to.equal(
    //     lockedAmount
    //   );
    // });

    // it("Should fail if the unlockTime is not in the future", async function () {
    //   // We don't use the fixture here because we want a different deployment
    //   const latestTime = await time.latest();
    //   const Lock = await ethers.getContractFactory("Lock");
    //   await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
    //     "Unlock time should be in the future"
    //   );
    // });
  });

  