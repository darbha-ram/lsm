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
        const from = "0x12345678";
        const res = await myLibsTest.callNewLeg();
        expect(res).to.equal("12Aug.1510");

    });

    


  });

