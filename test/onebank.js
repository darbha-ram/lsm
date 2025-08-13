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

        // deploy one bank contract
        confact = await ethers.getContractFactory("CorrACoin");
        basecon = await confact.deploy();
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

    it("verify contracts with libraries installed and accessible", async function () {
        const { corracoinCon, netterCon, paysysCon } = await loadFixture(setupContractsFixture);

        const netterVer = await netterCon.myver();
        expect(netterVer).to.equal("13Aug.1225");
        const paysysVer = await paysysCon.myver();
        expect(paysysVer).to.equal("13Aug.1230");
        const coinName = await corracoinCon.symbol();
        expect(coinName).to.equal("CorrA$");
    });

    it("add and find payment", async function() {
        const { corracoinCon, paysysCon } = await loadFixture(setupContractsFixture);

        const toAddr   = "0xD8dfE02d0eD3Ff0E9fc100EdE06244c28d6f3655";
        const amount = 123125;
        const erc20Addr = await corracoinCon.getAddress();

        // add intention to pay - this returns a receipt, not the PID! It sets lastPid..
        const resp = await paysysCon.intentToPay(toAddr, amount, erc20Addr);

        // .. which can be read via a getter (view) API
        const pid1 = await paysysCon.lastPid();
        expect(pid1.length).to.equal(66);

        // retrieve and check payment details
        const leg = await paysysCon.getPayment(pid1);
        expect(leg.to).to.equal(toAddr);
        expect(leg.amount).to.equal(123125n);
        expect(leg.erc20).to.equal(erc20Addr);

        const badId = "0x4a520f0a421f62b0f867894d6c6351ac3ca1fad8ee6247601c7c0e5768d96ab2";
        await expect(paysysCon.getPayment(badId)).to.be
            .revertedWith("Invalid payment ID not found: 0x4a520f0a421f62b0f867894d6c6351ac3ca1fad8ee6247601c7c0e5768d96ab2");

    });

    it("delete payment", async function() {
        const { corracoinCon, paysysCon } = await loadFixture(setupContractsFixture);

        const toAddr   = "0xD8dfE02d0eD3Ff0E9fc100EdE06244c28d6f3655";
        const amount = 123125;
        const erc20Addr = await corracoinCon.getAddress();

        // add intention to pay - this returns a receipt, not the PID! It sets lastPid..
        const resp = await paysysCon.intentToPay(toAddr, amount, erc20Addr);

        // .. which can be read via a getter (view) API
        const pid1 = await paysysCon.lastPid();

        // delete this payment
        await paysysCon.deletePayment(pid1);

        // verify it can no longer be retrieved
        await expect(paysysCon.getPayment(pid1)).to.be
            .revertedWith("Invalid payment ID not found: " + pid1);

    });

    /*
    it("add and find multiple payments", async function() {

    });

    it("net one payment", async function() {

    });

    it("net outgoing payments from 1 party", async function() {

    });

    it("net incoming payments from 1 party", async function() {

    });

    it("net incoming & outgoing payments from 1 party", async function() {

    });

    it("net incoming & outgoing payments from 3 parties", async function() {

    });
    */


  });
















