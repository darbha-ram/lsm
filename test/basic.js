const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

////////////////////////////////////////////////////////////////////////////////////////////////
// To execute:
//     $ npx hardhat node
//     $ npx hardhat --network localhost test test/basic.js
//
////////////////////////////////////////////////////////////////////////////////////////////////

describe("Libraries", function () {

    let myLibsTest;

    beforeEach(async function () {

        // deploy libraries first
        confact = await hre.ethers.getContractFactory("Common");
        basecon = await confact.deploy();
        commonLib = await basecon.waitForDeployment();
        const commonAddr = await commonLib.getAddress();

        confact = await hre.ethers.getContractFactory("HashConverter");
        basecon = await confact.deploy();
        hashLib = await basecon.waitForDeployment();
        const hashAddr = await hashLib.getAddress();

        // deploy test contract that wraps the 2 libraries, giving it 2 addresses
        const MyLibsTest = await ethers.getContractFactory("MyLibsTest", {
            libraries: {
                Common: commonAddr,
                HashConverter: hashAddr
            }
          }
        );
        myLibsTest = await MyLibsTest.deploy();
        await myLibsTest.waitForDeployment();
    });

    it("verify MyLibsTest installed and accessible", async function () {
        const res = await myLibsTest.myver();
        expect(res).to.equal("12Aug.1510");

    });

    
    it("create new payment leg", async function () {
        const fromAddr = "0xE74D3B7eC9Ad1E2341abc69D22F2820B88d4D62b";
        const toAddr   = "0xD8dfE02d0eD3Ff0E9fc100EdE06244c28d6f3655";
        const res = await myLibsTest.callNewLeg(fromAddr, toAddr, 1000, toAddr);
        expect(res.from).to.equal(fromAddr);
        expect(res.to).to.equal(toAddr);
        expect(res.amount).to.equal(1000n);
        expect(res.erc20).to.equal(toAddr);

    });

    


  });

