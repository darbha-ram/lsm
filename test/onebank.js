const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers");
const { ethers } = require("hardhat");


////////////////////////////////////////////////////////////////////////////////////////////////
// Test cases for netting payments all in a single money supply e.g., 1 CoBM
// To execute:
//     $ npx hardhat node
//     $ npx hardhat --network localhost test test/onebank.js
//
////////////////////////////////////////////////////////////////////////////////////////////////


describe("Netting in a single bank", function () {

    async function setupContractsFixture() {

        // deploy libraries first
        confact = await hre.ethers.getContractFactory("Common");
        basecon = await confact.deploy();
        commonLib = await basecon.waitForDeployment();
        const commonAddr = await commonLib.getAddress();

        confact = await hre.ethers.getContractFactory("HashConverter");
        basecon = await confact.deploy();
        hashLib = await basecon.waitForDeployment();
        const hashAddr = await hashLib.getAddress();

        // deploy one bank contract CorrACoin which is signer[1] - see README
        confact = await ethers.getContractFactory("CorrACoin");
        const sigs = await ethers.getSigners();
        basecon = await confact.connect(sigs[1]).deploy();
        const corracoinCon = await basecon.waitForDeployment();
        //const corracoinAddr = await corracoinCon.getAddress();

        // deploy MultilateralNetter contract - with 1 lib
        confact = await ethers.getContractFactory("MultilateralNetter", {
            libraries: {
                Common: commonAddr
            }
          }
        );
        basecon = await confact.deploy();
        const netterCon = await basecon.waitForDeployment();
        const netterAddr = await netterCon.getAddress();

        // deploy PaymentSystem contract - with 2 libs
        basecon = await ethers.deployContract("PaymentSystem", [netterAddr], {
            libraries: {
                Common: commonAddr,
                HashConverter: hashAddr
            }
          }
        );
        paysysCon = await basecon.waitForDeployment();
        //const paysysAddr = await paysysCon.getAddress();
    
        return { corracoinCon, netterCon, paysysCon };
    }

    //////////////////////////////////////////////////////////////////////////////////
    //
    it("verify contracts with libraries installed and accessible", async function () {
        const { corracoinCon, netterCon, paysysCon } = await loadFixture(setupContractsFixture);

        const netterVer = await netterCon.myver();
        expect(netterVer).to.equal("13Aug.1225");
        const paysysVer = await paysysCon.myver();
        expect(paysysVer).to.equal("14Aug.1530");
        const coinName = await corracoinCon.symbol();
        expect(coinName).to.equal("CorrA$");
    });

    //////////////////////////////////////////////////////////////////////////////////
    //
    it("add and find payment", async function() {
        const { corracoinCon, paysysCon } = await loadFixture(setupContractsFixture);

        const toAddr   = "0xD8dfE02d0eD3Ff0E9fc100EdE06244c28d6f3655";
        const amount = 123125;
        const erc20Addr = await corracoinCon.getAddress();

        // add raw payment - this returns a receipt, not the PID! It sets lastRawPid..
        const resp = await paysysCon.addRawPayment(toAddr, amount, erc20Addr);

        // .. which can be read via a getter (view) API
        const pid1 = await paysysCon.lastRawPid();
        expect(pid1.length).to.equal(66);

        // retrieve and check payment details
        const leg = await paysysCon.getRawPayment(pid1);
        expect(leg.to).to.equal(toAddr);
        expect(leg.amount).to.equal(123125n);
        expect(leg.erc20).to.equal(erc20Addr);

        const badId = "0x4a520f0a421f62b0f867894d6c6351ac3ca1fad8ee6247601c7c0e5768d96ab2";
        await expect(paysysCon.getRawPayment(badId)).to.be
            .revertedWith("Invalid payment ID not found: 0x4a520f0a421f62b0f867894d6c6351ac3ca1fad8ee6247601c7c0e5768d96ab2");

    });

    //////////////////////////////////////////////////////////////////////////////////
    //
    it("delete payment", async function() {
        const { corracoinCon, paysysCon } = await loadFixture(setupContractsFixture);

        const toAddr   = "0xD8dfE02d0eD3Ff0E9fc100EdE06244c28d6f3655";
        const amount = 123125;
        const erc20Addr = await corracoinCon.getAddress();

        // add raw payment - this returns a receipt, not the PID! It sets lastRawPid..
        const resp = await paysysCon.addRawPayment(toAddr, amount, erc20Addr);

        // .. which can be read via a getter (view) API
        const pid1 = await paysysCon.lastRawPid();

        // delete this payment
        await paysysCon.deleteRawPayment(pid1);

        // verify it can no longer be retrieved
        await expect(paysysCon.getRawPayment(pid1)).to.be
            .revertedWith("Invalid payment ID not found: " + pid1);

    });

    //////////////////////////////////////////////////////////////////////////////////
    //
    it("add and find multiple payments", async function() {
        const { corracoinCon, paysysCon } = await loadFixture(setupContractsFixture);

        const erc20Addr = await corracoinCon.getAddress();
        const toAddr1   = "0xE74D3B7eC9Ad1E2341abc69D22F2820B88d4D62b"
        const amount1 = 111111;
        const toAddr2   = "0xD8dfE02d0eD3Ff0E9fc100EdE06244c28d6f3655";
        const amount2 = 222222;

        // add raw payment - returns a receipt. Read lastRawPid set by it
        resp = await paysysCon.addRawPayment(toAddr1, amount1, erc20Addr);
        const pid1 = await paysysCon.lastRawPid();
        // .. and raw payment #2
        resp = await paysysCon.addRawPayment(toAddr2, amount2, erc20Addr);
        const pid2 = await paysysCon.lastRawPid();

        // retrieve and verify each
        leg = await paysysCon.getRawPayment(pid1);
        expect(leg.to).to.equal(toAddr1);
        expect(leg.amount).to.equal(111111n);
        expect(leg.erc20).to.equal(erc20Addr);

        leg = await paysysCon.getRawPayment(pid2);
        expect(leg.to).to.equal(toAddr2);
        expect(leg.amount).to.equal(222222n);
        expect(leg.erc20).to.equal(erc20Addr);
    });

    //////////////////////////////////////////////////////////////////////////////////
    //
    it("net one payment", async function() {
        const { corracoinCon, paysysCon } = await loadFixture(setupContractsFixture);

        // default signer0 is the 'from' address, store it to check later
        const sigs = await ethers.getSigners();
        const sig0Addr = sigs[0].address;

        const erc20Addr = await corracoinCon.getAddress();
        const toAddr    = "0xE74D3B7eC9Ad1E2341abc69D22F2820B88d4D62b";
        const amount    = 123;

        // add raw payment - returns a receipt. Read lastRawPid set by it
        resp = await paysysCon.addRawPayment(toAddr, amount, erc20Addr);
        const pid1 = await paysysCon.lastRawPid();

        // run netting process
        resp = await paysysCon.performNetting();

        // verify that result of netting 1 orig payment is 2 payments, as below
        // fromAddr -> toAddr is decomposed to
        //   (1) fromAddr -> erc20 contract
        //   (2) erc20 contract -> toAddr
        const numItems = await paysysCon.numNetted();
        expect(numItems).to.equal(2);

        // 1st netted payment: fromAddr -> erc20 contract
        const item0 = await paysysCon.nettedPayments(0);
        //console.log(item0);
        expect(item0.from).to.equal(sig0Addr);
        expect(item0.to).to.equal(erc20Addr);
        expect(item0.amount).to.equal(123n);
        expect(item0.erc20).to.equal(erc20Addr);

        // 2nd netted payment: erc20 contract -> toAddr
        const item1 = await paysysCon.nettedPayments(1);
        //console.log(item1);
        expect(item1.from).to.equal(erc20Addr);
        expect(item1.to).to.equal(toAddr);
        expect(item1.amount).to.equal(123n);
        expect(item1.erc20).to.equal(erc20Addr);
        
        // to issue transactions on same contract using other signers
        //const item2 = await paysysCon.connect(sigs[1]).nettedPayments(1);

    });

    //////////////////////////////////////////////////////////////////////////////////
    //
    it("net incoming & outgoing payments from 1 party", async function() {
        const { corracoinCon, paysysCon } = await loadFixture(setupContractsFixture);

        // money supply
        const erc20Addr = await corracoinCon.getAddress();

        // to get signer addresses to act as 'from' and 'to'
        const sigs = await ethers.getSigners();

        // 3 payments: sig0 has in & out payments, rest are unidirectional
        // sig0 -> sig1 $100
        // sig0 -> sig2 $200
        // sig3 -> sig0  $75

        // add 3 raw payments
        await paysysCon.connect(sigs[0]).addRawPayment(sigs[1].address, 100, erc20Addr);
        await paysysCon.connect(sigs[0]).addRawPayment(sigs[2].address, 200, erc20Addr);
        await paysysCon.connect(sigs[3]).addRawPayment(sigs[0].address,  75, erc20Addr);

        // run netting process
        resp = await paysysCon.performNetting();

        // after netting: verify 4 netted payments -- these may be in any order, but
        // because we use Solidity push() which appends at the end, we can guess what
        // that they would in the order below:
        // sig0  -> erc20 $225
        // erc20 -> sig1  $100
        // erc20 -> sig2  $200
        // sig3  -> erc20  $75

        const numItems = await paysysCon.numNetted();
        expect(numItems).to.equal(4);

        const item0 = await paysysCon.nettedPayments(0);
        expect(item0.from).to.equal(sigs[0].address);
        expect(item0.to).to.equal(erc20Addr);
        expect(item0.amount).to.equal(225n);
        expect(item0.erc20).to.equal(erc20Addr);

        const item1 = await paysysCon.nettedPayments(1);
        expect(item1.from).to.equal(erc20Addr);
        expect(item1.to).to.equal(sigs[1].address);
        expect(item1.amount).to.equal(100n);
        expect(item1.erc20).to.equal(erc20Addr);

        const item2 = await paysysCon.nettedPayments(2);
        expect(item2.from).to.equal(erc20Addr);
        expect(item2.to).to.equal(sigs[2].address);
        expect(item2.amount).to.equal(200n);
        expect(item2.erc20).to.equal(erc20Addr);

        const item3 = await paysysCon.nettedPayments(3);
        expect(item3.from).to.equal(sigs[3].address);
        expect(item3.to).to.equal(erc20Addr);
        expect(item3.amount).to.equal(75n);
        expect(item3.erc20).to.equal(erc20Addr);

    });

    //////////////////////////////////////////////////////////////////////////////////
    //
    it("net incoming & outgoing payments among 5 parties", async function() {
        const { corracoinCon, paysysCon } = await loadFixture(setupContractsFixture);

        // money supply
        const erc20Addr = await corracoinCon.getAddress();

        // to get signer addresses to act as 'from' and 'to'
        const sigs = await ethers.getSigners();

        // raw payments: sig0 is out-only; sig1 is in-only; sig2 is in/out net zero;
        //   sig3 and sig4 are in/out net non-zero.
        // sig0 -> sig1 $50
        // sig0 -> sig2 $200
        // sig0 -> sig4  $75
        // sig2 -> sig1 $300
        // sig3 -> sig2 $100
        // sig4 -> sig1  $25
        // sig4 -> sig3 $175

        // input order of records above determines order after netting: 0, 1, 2, 4, 3

        // add all the raw payments
        await paysysCon.connect(sigs[0]).addRawPayment(sigs[1].address, 50, erc20Addr);
        await paysysCon.connect(sigs[0]).addRawPayment(sigs[2].address, 200, erc20Addr);
        await paysysCon.connect(sigs[0]).addRawPayment(sigs[4].address, 75, erc20Addr);

        await paysysCon.connect(sigs[2]).addRawPayment(sigs[1].address, 300, erc20Addr);

        await paysysCon.connect(sigs[3]).addRawPayment(sigs[2].address, 100, erc20Addr);

        await paysysCon.connect(sigs[4]).addRawPayment(sigs[1].address, 25, erc20Addr);
        await paysysCon.connect(sigs[4]).addRawPayment(sigs[3].address, 175, erc20Addr);

        // run netting process
        resp = await paysysCon.performNetting();

        // verify after netting
        // sig0 -> 325
        // sig1 <- 375
        // sig2 zero!   (no entry for this)
        // sig3 <- 75  (this is last entry!)
        // sig4 -> 125 (this is last-but-one entry!)

        const numItems = await paysysCon.numNetted();
        expect(numItems).to.equal(4);

        const item0 = await paysysCon.nettedPayments(0);
        expect(item0.from).to.equal(sigs[0].address);
        expect(item0.to).to.equal(erc20Addr);
        expect(item0.amount).to.equal(325n);
        expect(item0.erc20).to.equal(erc20Addr);

        const item1 = await paysysCon.nettedPayments(1);
        expect(item1.from).to.equal(erc20Addr);
        expect(item1.to).to.equal(sigs[1].address);
        expect(item1.amount).to.equal(375n);
        expect(item1.erc20).to.equal(erc20Addr);
        
        const item3 = await paysysCon.nettedPayments(2);
        expect(item3.from).to.equal(sigs[4].address);
        expect(item3.to).to.equal(erc20Addr);
        expect(item3.amount).to.equal(125n);
        expect(item3.erc20).to.equal(erc20Addr);

        const item4 = await paysysCon.nettedPayments(3);
        expect(item4.from).to.equal(erc20Addr);
        expect(item4.to).to.equal(sigs[3].address);
        expect(item4.amount).to.equal(75n);
        expect(item4.erc20).to.equal(erc20Addr);

    });


  });
















