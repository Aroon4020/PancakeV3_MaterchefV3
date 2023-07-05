import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { parse } from "path";
import { parseEther } from "ethers";
import { ethers } from "hardhat";
import { expect } from "chai";
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

async function deploy_CAKE_ETH_Vault() {
  let name = "A";
  let sysmbol = "B";
  let tickLower = "111";
  let tickUpper = "111";
  let pool = "0x133B3D95bAD5405d14d53473671200e9342896BF"
  // let route0 = [
  //   "0xd4d42F0b6DEF4CE0383636770eF773390d85c61A",
  //   "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
  // ];
  // let approveToken = [
  //   "0x3082CC23568eA640225c2467653dB90e9250AaA0",
  //   "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
  //   "0xd4d42F0b6DEF4CE0383636770eF773390d85c61A",
  // ];
  const [user0] = await ethers.getSigners();
  const SwapLib = await ethers.getContractFactory("Swap");
  const swaplib = await SwapLib.deploy();
  let a = await swaplib.getAddress();
  console.log(a);
  console.log(swaplib);
  // const LiquidityLib = await ethers.getContractFactory("Liquidity");
  // const liquiditylib = await LiquidityLib.deploy();
  //liquiditylib.address
  //await liquiditylib.deployed
  // const VAULT = await ethers.getContractFactory("Vault",{
  //   libraries:{
  //     Liquidity:"0x133B3D95bAD5405d14d53473671200e9342896BF",
  //     Swap:"0x133B3D95bAD5405d14d53473671200e9342896BF",
  //   },
  // });
  // const vault = await VAULT.deploy(
  //   name,
  //   sysmbol,
  //   tickLower,
  //   tickUpper,
  //   pool,
  // );
  //await ethers.provider.getSigner().link(vault.address, swaplib.address,liquiditylib.address);
  //vault.address
  // const [, signer0] = await ethers.getSigners();
  // const txSigner0 = vault.connect(signer0);

  return { swaplib};
}



  describe("ZAP and VAULT", function () {
    it("test Vault",async () => {
      const { vault } = await loadFixture(deploy_CAKE_ETH_Vault);
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

  