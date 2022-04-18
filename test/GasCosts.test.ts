import {
  ContractFactory,
  Contract,
  ContractReceipt,
  ContractTransaction,
  Event,
} from "@ethersproject/contracts";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Address } from "cluster";
import { BigNumber, Bytes } from "ethers";
import { ethers } from "hardhat";

describe("GasCosts contract", function () {
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  let gcFactory: ContractFactory;
  let gc: Contract;

  before(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    // console.log("Created signers. Owner:", owner.address);

    // Deploy the contract
    gcFactory = await ethers.getContractFactory("GasCosts");
    gc = await gcFactory.deploy();
    console.log("Deployed GasCosts");
  });

  describe("Test", function () {
    it("Should have tested function", async function () {
      await gc.testset();
      expect(await gc.testnum()).to.equal(
        "0x3078310000000000000000000000000000000000000000000000000000000000"
      );
    });
  });

  describe("GasCost", function () {
    it("Should have tested gas costs", async function () {
      await gc.CreateReport();
      expect(1).to.equal(1);
    });
  });
});
