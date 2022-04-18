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

import DOXERC20 from "../artifacts/contracts/DOXERC20.sol/DOXERC20.json";

describe("ParadoxV1 contract", function () {
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  let tokenFactoryFactory: ContractFactory;
  let tokenFactory: Contract;
  let token1: Contract;
  let token2: Contract;
  let token3: Contract;
  let doxFactory: ContractFactory;
  let dox: Contract;

  let token1Address: string;
  let token2Address: string;
  let token3Address: string;

  before(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    // console.log("Created signers. Owner:", owner.address);

    // Deploy the test ERC20 token
    tokenFactoryFactory = await ethers.getContractFactory("DOXERC20Factory");
    tokenFactory = await tokenFactoryFactory.deploy();
    console.log("tokenFactory Address: ", tokenFactory.address);

    var transaction = await tokenFactory.createToken(
      "BASH token",
      "BASH",
      50000000
    );
    await transaction.wait();
    token1Address = await tokenFactory.getToken("BASH");
    token1 = new ethers.Contract(token1Address, DOXERC20.abi, owner);

    transaction = await tokenFactory.createToken(
      "CASH token",
      "CASH",
      50000000
    );
    await transaction.wait();
    token2Address = await tokenFactory.getToken("CASH");
    token2 = new ethers.Contract(token2Address, DOXERC20.abi, owner);

    transaction = await tokenFactory.createToken(
      "DASH token",
      "DASH",
      50000000
    );
    await transaction.wait();
    token3Address = await tokenFactory.getToken("DASH");
    token3 = new ethers.Contract(token3Address, DOXERC20.abi, owner);

    console.log(
      "Deployed tokens: ",
      token1Address,
      token2Address,
      token3Address
    );

    // Deploy the DOX Contract
    doxFactory = await ethers.getContractFactory("ParadoxV1");
    dox = await doxFactory.deploy();
    console.log("Deployed ParadoxV1: ", dox.address);

    // Approve and transfer 100 from ERC20 to DOX contract
    await token1.approve(dox.address, 20000000);
    await dox.deposit(token1.address, 20000000);
    await token2.approve(dox.address, 30000000);
    await dox.deposit(token2.address, 30000000);
    await token3.approve(dox.address, 20000000);
    await dox.deposit(token3.address, 20000000);
    console.log(
      "Deployed ParadoxV1 contract and deposited initial 100 to owner on token1"
    );
  });

  describe("Deployment", function () {
    it("Should have set the right owner", async function () {
      expect(await dox.owner()).to.equal(owner.address);
    });
  });

  describe("AddLiquidity", async function () {
    it("Should have added liquidity to the token1-token2 pair", async function () {
      await dox.addLiquidity(
        token1.address,
        token2.address,
        10000000,
        10000000
      );
      const [cpi, order] = await dox.findCPI(token1.address, token2.address);
      expect(cpi.a).to.equal(10000000);
      expect(cpi.b).to.equal(10000000);
    });
    it("Should have lower token1&2 balances due to adding liquidity", async function () {
      const bal1 = await dox.getBook(owner.address, token1.address);
      const bal2 = await dox.getBook(owner.address, token2.address);
      expect(bal1).to.equal(10000000);
      expect(bal2).to.equal(20000000);
    });
    it("Should have added liquidity to the token2-token3 pair", async function () {
      await dox.addLiquidity(
        token2.address,
        token3.address,
        10000000,
        10000000
      );
      const [cpi, order] = await dox.findCPI(token2.address, token3.address);
      expect(cpi.a).to.equal(10000000);
      expect(cpi.b).to.equal(10000000);
    });
    it("Should have lower token2&3 balances due to adding liquidity", async function () {
      const bal2 = await dox.getBook(owner.address, token2.address);
      const bal3 = await dox.getBook(owner.address, token3.address);
      expect(bal2).to.equal(10000000);
      expect(bal3).to.equal(10000000);
    });
  });

  // describe("Swap2", async function () {
  //   for (let i = 0; i < 5; i++) {
  //     it("Should have swapped token1 for token2", async function () {
  //       await dox.swap(
  //         owner.address,
  //         token1.address,
  //         token2.address,
  //         token3.address,
  //         100000
  //       );
  //       const bal1 = await dox.getBook(owner.address, token1.address);
  //       const bal2 = await dox.getBook(owner.address, token2.address);
  //       console.log(
  //         "post-swap balances: ",
  //         BigNumber.from(bal1).toString(),
  //         BigNumber.from(bal2).toString()
  //       );
  //       expect(1).to.equal(1);
  //     });
  //   }
  // });

  describe("Swap", async function () {
    var token1bal = 10000000;
    var token2bal = 10000000;
    let k = token1bal * token2bal;

    var bal1last = 10000000;
    var bal2last = 10000000;
    let swapAmt = 10000;

    for (let i = 0; i < 7; i++) {
      it("Should have swapped token1 for token2", async function () {
        await dox.swap(token1.address, token2.address, swapAmt);

        let token2LastPx = token2bal / token1bal;
        token1bal = token1bal + swapAmt;
        let token2baldiff = token2bal - k / token1bal;
        token2bal = k / token1bal;
        console.log(
          "token calcs: ",
          token1bal.toFixed(2),
          token2bal.toFixed(2),
          token2baldiff.toFixed(2)
        );
        let token2Px = token2bal / token1bal;
        console.log(
          "token2 px last, current, slippage: ",
          token2LastPx.toFixed(4),
          token2Px.toFixed(4),
          ((token2Px - token2LastPx) / token2LastPx).toFixed(4) + "%"
        );

        const bal1 = await dox.getBook(owner.address, token1.address);
        const bal2 = await dox.getBook(owner.address, token2.address);
        console.log(
          "post-swap balances: ",
          BigNumber.from(bal1).toString(),
          BigNumber.from(bal2).toString()
        );

        bal1last = bal1last - swapAmt;
        bal2last = bal2last + token2baldiff;

        console.log(
          "last balances: ",
          bal1last.toFixed(2),
          bal2last.toFixed(2)
        );
        expect(Math.ceil(bal1)).to.equal(Math.ceil(bal1last));
        expect(Math.ceil(bal2)).to.equal(Math.ceil(bal2last));
      });
    }
  });

  // describe("Balance", function () {
  //   it("Should have book value of 100 erc20 for sender", async function () {
  //     const book = await dox.getBook(owner.address, token1.address);
  //     expect(book).to.equal(100);
  //   });

  //   it("Should have token balance of 49900 for sender on deployed erc20", async function () {
  //     const balance = await token1.balanceOf(owner.address);
  //     expect(balance).to.equal(49900);
  //   });
  // });

  // describe("Deposit", function () {
  //   it("Should have deposited 100 more for a book value of 200 for sender on erc20", async function () {
  //     await token1.approve(dox.address, 100);
  //     await dox.deposit(token1.address, 100);
  //     const book = await dox.getBook(owner.address, token1.address);
  //     expect(book).to.equal(200);
  //   });
  // });

  // describe("Balance", function () {
  //   it("Should have book value of 200 erc20 for sender", async function () {
  //     const book = await dox.getBook(owner.address, token1.address);
  //     expect(book).to.equal(200);
  //   });

  //   it("Should have token balance of 49800 for sender on deployed erc20", async function () {
  //     const balance = await token1.balanceOf(owner.address);
  //     expect(balance).to.equal(49800);
  //   });
  // });

  // describe("Transfer", function () {
  //   it("Should have transferred 30 from owner", async function () {
  //     await dox.transfer(token1.address, account2.address, 30);
  //     const book = await dox.getBook(owner.address, token1.address);
  //     expect(book).to.equal(170);
  //   });
  //   it("Should have transferred 30 to account2", async function () {
  //     const book = await dox.getBook(account2.address, token1.address);
  //     expect(book).to.equal(30);
  //   });
  // });

  // describe("Mint", function () {
  //   it("Should have minted an ERC20 token with symbol nDASH", async function () {
  //     await dox.mint("nDASH");
  //     const doxOwner = await dox.getTpOwner("nDASH");
  //     expect(doxOwner).to.equal(owner.address);
  //   });
  // });

  // describe("Fill", function () {
  //   it("Should have filled the ERC20 token with 100 erc20", async function () {
  //     await dox.fill("nDASH", token1.address, 100);
  //     const tpBalance = await dox.getTp("nDASH", token1.address);
  //     expect(tpBalance).to.equal(100);
  //   });
  // });

  // describe("Balance", function () {
  //   it("Should have book value of 70 erc20 for sender", async function () {
  //     const book = await dox.getBook(owner.address, token1.address);
  //     expect(book).to.equal(70);
  //   });
  // });

  // describe("Drain", function () {
  //   it("Should have drained the ERC20 token down to 40 erc20", async function () {
  //     await dox.drain("nDASH", token1.address, 60);
  //     const tpBalance = await dox.getTp("nDASH", token1.address);
  //     expect(tpBalance).to.equal(40);
  //   });
  // });

  // describe("Balance", function () {
  //   it("Should have book value of 130 erc20 for sender", async function () {
  //     const book = await dox.getBook(owner.address, token1.address);
  //     expect(book).to.equal(130);
  //   });
  // });

  // describe("Assign", function () {
  //   it("Should have assigned ERC20 token from owner to account2", async function () {
  //     // const ns = Array.from(Array(2000).keys());
  //     // ns.forEach(async (n) => await dox.mint("nDASH" + n));
  //     await dox.assign("nDASH", account2.address);
  //     const tpOwner = await dox.getTpOwner("nDASH");
  //     expect(tpOwner).to.equal(account2.address);
  //   });
  // });

  // describe("Withdraw", function () {
  //   it("Should have withdrawn 100 for sender on erc20", async function () {
  //     await dox.withdraw(token1.address, 100);
  //     const book = await dox.getBook(owner.address, token1.address);
  //     expect(book).to.equal(30);
  //   });
  // });

  // describe("Balance", function () {
  //   it("Should have book value of 30 erc20 for sender", async function () {
  //     const book = await dox.getBook(owner.address, token1.address);
  //     expect(book).to.equal(30);
  //   });

  //   it("Should have token balance of 400 for sender on deployed erc20", async function () {
  //     const balance = await token1.balanceOf(owner.address);
  //     expect(balance).to.equal(400);
  //   });
  // });
});
