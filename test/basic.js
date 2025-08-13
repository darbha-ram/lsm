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
        const res = await myLibsTest.callNewLeg(fromAddr, toAddr, 100257, toAddr);
        expect(res.from).to.equal(fromAddr);
        expect(res.to).to.equal(toAddr);
        expect(res.amount).to.equal(100257n);
        expect(res.erc20).to.equal(toAddr);
    });

    it("convert hash between bytes32 and string", async function () {
        const idStringOrig = "0x4a520f0a421f62b0f867894d6c6351ac3ca1fad8ee6247601c7c0e5768d96ab2";
        const idBytes      = await myLibsTest.callHexStringToBytes32(idStringOrig);
        const idStringNew  = await myLibsTest.callToHexString(idBytes);

        expect(idStringNew.length).to.equal(66); // 64 + '0x' prefix
        expect(idStringNew).to.equal(idStringOrig);

        const rawBytes = ethers.getBytes(idBytes);
        expect(rawBytes.length).to.equal(32);
        expect(rawBytes[0]).to.equal(0x4a);
        expect(rawBytes[1]).to.equal(0x52);
        expect(rawBytes[2]).to.equal(0x0f);
        expect(rawBytes[3]).to.equal(0x0a);
        expect(rawBytes[4]).to.equal(0x42);
        expect(rawBytes[5]).to.equal(0x1f);
        expect(rawBytes[6]).to.equal(0x62);
        expect(rawBytes[7]).to.equal(0xb0);
        expect(rawBytes[8]).to.equal(0xf8);
        expect(rawBytes[9]).to.equal(0x67);

        expect(rawBytes[10]).to.equal(0x89);
        expect(rawBytes[11]).to.equal(0x4d);
        expect(rawBytes[12]).to.equal(0x6c);
        expect(rawBytes[13]).to.equal(0x63);
        expect(rawBytes[14]).to.equal(0x51);
        expect(rawBytes[15]).to.equal(0xac);
        expect(rawBytes[16]).to.equal(0x3c);
        expect(rawBytes[17]).to.equal(0xa1);
        expect(rawBytes[18]).to.equal(0xfa);
        expect(rawBytes[19]).to.equal(0xd8);

        expect(rawBytes[20]).to.equal(0xee);
        expect(rawBytes[21]).to.equal(0x62);
        expect(rawBytes[22]).to.equal(0x47);
        expect(rawBytes[23]).to.equal(0x60);
        expect(rawBytes[24]).to.equal(0x1c);
        expect(rawBytes[25]).to.equal(0x7c);
        expect(rawBytes[26]).to.equal(0x0e);
        expect(rawBytes[27]).to.equal(0x57);
        expect(rawBytes[28]).to.equal(0x68);
        expect(rawBytes[29]).to.equal(0xd9);
        expect(rawBytes[30]).to.equal(0x6a);
        expect(rawBytes[31]).to.equal(0xb2);

        //console.log("hex string of ID is: ", idString);
    });

    


  });

