const { expect } = require("chai");
const { ethers } = require("hardhat");

const MILLION = ethers.BigNumber.from("1000000");
const TCKO = MILLION;
const QUARTER_MIL = ethers.BigNumber.from("250000");

async function gas(tx) {
    const receipt = await tx.wait();
    console.log("Gas: " + receipt.cumulativeGasUsed.toString());
}

describe("Minting, distribution and unlocking", function () {
    let signers;
    let daoKasasi;
    let tckok;
    let tcko;

    beforeEach(async function () {
        await ethers.provider.send("hardhat_reset");
        signers = await ethers.getSigners();

        const DAOKasasi = await ethers.getContractFactory("MockDAOKasasi");
        const KilitliTCKO = await ethers.getContractFactory("KilitliTCKO");
        const TCKO = await ethers.getContractFactory("TCKO");
        daoKasasi = await DAOKasasi.deploy();
        tckok = await KilitliTCKO.deploy();
        tcko = await TCKO.deploy();

        await tcko.deployed();
        await tckok.setTCKOAddress(tcko.address);

        console.log("DAO_KASASI:   " + daoKasasi.address);
        console.log("KILITLI_TCKO: " + tckok.address);
        console.log("TCKO:         " + tcko.address);
    });

    let balances = async () => {
        let balT = async (index) => (await tcko.balanceOf(signers[index].address)).toString()
        let balK = async (index) => (await tckok.balanceOf(signers[index].address)).toString()

        console.log("User  Unlocked   Locked");
        console.log("------------------------------------------");
        console.log(`0:\t${await balT(0)},\t ${await balK(0)}`);
        console.log("------------------------------------------");
        for (let i = 1; i <= 20; ++i)
            console.log(`${i}:\t${await balT(i)},\t ${await balK(i)}`);
    }

    let mintAll = async (amount) => {
        for (let i = 1; i <= 20; ++i)
            await tcko.mint(signers[i].address, amount * MILLION);
    }

    it("Should complete all rounds", async function () {
        await mintAll(MILLION);
        const tckoSupply = await tcko.totalSupply();
        const tckoCap = await tcko.supplyCap();
        const tckokSupply = await tckok.totalSupply();

        expect(tckoSupply).to.equal(20 * MILLION * MILLION);
        expect(tckoCap).to.equal(tckoSupply);
        expect(3 * (tckoSupply - tckokSupply)).to.equal(tckokSupply);

        await tcko.connect(signers[1]).transfer(signers[2].address, QUARTER_MIL * TCKO);

        expect(await tcko.balanceOf(signers[1].address)).to.equal(0);
        expect(await tcko.balanceOf(signers[2].address)).to.equal(2 * QUARTER_MIL * TCKO);

        await tcko.incrementDistroStage(1); // Presale2

        await mintAll(MILLION);
        expect(await tcko.totalSupply()).to.equal(40 * MILLION * TCKO);
        expect(await tckok.totalSupply()).to.equal(30 * MILLION * TCKO);

        await tcko.incrementDistroStage(2); // DAOSaleStart

        expect(await tcko.totalSupply()).to.equal(60 * MILLION * TCKO);
        expect(await tckok.totalSupply()).to.equal(30 * MILLION * TCKO);

        await tcko.incrementDistroStage(3); // DAOSaleEnd

        await tckok.unlock(signers[1].address);
        await tckok.unlock(signers[2].address);

        expect(await tcko.balanceOf(signers[1].address)).to.equal(MILLION * TCKO);
        expect(await tcko.balanceOf(signers[2].address)).to.equal(6 * QUARTER_MIL * TCKO);

        await tckok.unlockAllEven();

        expect(await tckok.balanceOf(signers[1].address)).to.equal(3 * QUARTER_MIL * TCKO);
        expect(await tckok.balanceOf(signers[2].address)).to.equal(3 * QUARTER_MIL * TCKO);

        await tcko.incrementDistroStage(4); // DAOAMMStart

        expect(await tcko.totalSupply()).to.equal(80 * MILLION * TCKO);
        expect(await tckok.totalSupply()).to.equal(15 * MILLION * TCKO);

        await tcko.incrementDistroStage(5); // Presale2Unlock

        gas(await tckok.unlockAllOdd());

        await tcko.incrementDistroStage(6); // FinalMint

        await mintAll(MILLION);
        await tckok.unlock(signers[1].address);

        expect(await tckok.balanceOf(signers[1].address)).to.equal(3 * QUARTER_MIL * TCKO);

        ethers.provider.send("evm_setNextBlockTimestamp", [1925097600]);
        await tcko.incrementDistroStage(7); // FinalUnlock
        await tckok.unlock(signers[1].address);

        expect(await tckok.balanceOf(signers[1].address)).to.equal(0);

        await tckok.unlockAllEven();

        expect(await tckok.balanceOf(signers[07].address)).to.equal(0);
        expect(await tckok.balanceOf(signers[17].address)).to.equal(0);
        expect(await tckok.balanceOf(signers[19].address)).to.equal(0);

        expect(await tckok.totalSupply()).to.equal(0);

        await balances();
    });
});

describe("Redemption", async function () {
    let signers;
    let daoKasasi;
    let tckok;
    let tcko;

    beforeEach(async function () {
        signers = await ethers.getSigners();
        await ethers.provider.send("hardhat_reset");

        const DAOKasasi = await ethers.getContractFactory("MockDAOKasasi");
        const KilitliTCKO = await ethers.getContractFactory("KilitliTCKO");
        const TCKO = await ethers.getContractFactory("TCKO");
        daoKasasi = await DAOKasasi.deploy();
        tckok = await KilitliTCKO.deploy();
        tcko = await TCKO.deploy();

        await tcko.deployed();
        await tckok.setTCKOAddress(tcko.address);

        console.log("DAO_KASASI:   " + daoKasasi.address);
        console.log("KILITLI_TCKO: " + tckok.address);
        console.log("TCKO:         " + tcko.address);
    });

    let mintAll = async (amount) => {
        for (let i = 1; i <= 20; ++i)
            await tcko.mint(signers[i].address, amount * TCKO);
    }

    it("Should preserve totalSupply + totalBurned = totalMinted", async function () {
        await mintAll(MILLION);

        expect(await tcko.totalSupply()).to.equal(20 * MILLION * TCKO);
        expect(await tckok.totalSupply()).to.equal(15 * MILLION * TCKO);

        // Let the last 12 TCKO holders redeem their TCKOs.
        for (let i = 9; i <= 20; ++i) {
            await tcko.connect(signers[i]).transfer(daoKasasi.address, QUARTER_MIL * TCKO);
        }

        expect(await tcko.totalSupply()).to.equal(17 * MILLION * TCKO);
        expect(await tckok.totalSupply()).to.equal(15 * MILLION * TCKO);

        expect(await tcko.totalMinted()).to.equal(20 * MILLION * TCKO);

        await tcko.incrementDistroStage(1); // Presale2;

        await mintAll(MILLION);

        expect(await tcko.totalSupply()).to.equal(37 * MILLION * TCKO);

        // The same 12 people redeem their TCKOs. Paper hands are gonna paper-hand.
        for (let i = 9; i <= 20; ++i) {
            await tcko.connect(signers[i]).transfer(daoKasasi.address, QUARTER_MIL * TCKO);
        }

        expect(await tcko.totalSupply()).to.equal(34 * MILLION * TCKO);
    });
});


describe("Transfers", async function () {
    let signers;
    let daoKasasi;
    let tckok;
    let tcko;

    beforeEach(async function () {
        signers = await ethers.getSigners();
        await ethers.provider.send("hardhat_reset");

        const DAOKasasi = await ethers.getContractFactory("MockDAOKasasi");
        const KilitliTCKO = await ethers.getContractFactory("KilitliTCKO");
        const TCKO = await ethers.getContractFactory("TCKO");
        daoKasasi = await DAOKasasi.deploy();
        tckok = await KilitliTCKO.deploy();
        tcko = await TCKO.deploy();

        await tcko.deployed();
        await tckok.setTCKOAddress(tcko.address);

        console.log("DAO_KASASI:   " + daoKasasi.address);
        console.log("KILITLI_TCKO: " + tckok.address);
        console.log("TCKO:         " + tcko.address);
    });

    let balances = async () => {
        let balT = async (index) => (await tcko.balanceOf(signers[index].address)).toString()
        let balK = async (index) => (await tckok.balanceOf(signers[index].address)).toString()

        console.log("User  Unlocked   Locked");
        console.log("------------------------------------------");
        console.log(`0:\t${await balT(0)},\t ${await balK(0)}`);
        console.log("------------------------------------------");
        for (let i = 1; i <= 20; ++i)
            console.log(`${i}:\t${await balT(i)},\t ${await balK(i)}`);
    }

    let mintAll = async (amount) => {
        for (let i = 1; i <= 20; ++i)
            await tcko.mint(signers[i].address, amount * TCKO);
    }

    it("Should preserve individual balances", async function () {
        await mintAll(4);

        for (let i = 1; i < 20; ++i) {
            await tcko.connect(signers[i]).transfer(signers[i + 1].address, 1 * TCKO);
        }

        expect(await tcko.balanceOf(signers[1].address)).to.equal(0 * TCKO);
        expect(await tcko.balanceOf(signers[2].address)).to.equal(1 * TCKO);
        expect(await tcko.balanceOf(signers[20].address)).to.equal(2 * TCKO);
    });

    it("Should not allow overspending", async function () {
        await mintAll(4);

        await expect(tcko.connect(signers[1]).transfer(signers[2].address, 2 * TCKO)).to.be.reverted;
        await tcko.connect(signers[3]).transfer(signers[4].address, TCKO);

        await expect(tcko.connect(signers[4]).transfer(signers[5].address, 3 * TCKO)).to.be.reverted;
    });

    it("Should let authorized parties spend on owners behalf", async function () {
        await mintAll(4);

        await tcko.connect(signers[1]).approve(signers[2].address, 1 * TCKO);

        expect(await tcko.allowance(signers[1].address, signers[2].address)).to.equal(1 * TCKO);

        await tcko.connect(signers[2]).transferFrom(signers[1].address, signers[3].address, 1 * TCKO);

        expect(await tcko.allowance(signers[1].address, signers[2].address)).to.equal(0 * TCKO);

        await expect(tcko.connect(signers[2]).transferFrom(signers[1].address, signers[3].address, 1 * TCKO)).to.be.reverted;
    });

    it("Should let users adjust allowance", async function () {
        await mintAll(4);

        await tcko.connect(signers[1]).increaseAllowance(signers[2].address, 3 * TCKO);
        await expect(tcko.connect(signers[1]).increaseAllowance(signers[2].address, ethers.constants.MaxUint256)).to.be.reverted;
        await expect(tcko.connect(signers[1]).decreaseAllowance(signers[2].address, 4 * TCKO)).to.be.reverted;

        await tcko.connect(signers[1]).decreaseAllowance(signers[2].address, 2 * TCKO);
        await expect(tcko.connect(signers[2]).transferFrom(signers[1].address, signers[2].address, 2 * TCKO)).to.be.reverted;
        await tcko.connect(signers[2]).transferFrom(signers[1].address, signers[2].address, 1 * TCKO);
        expect(await tcko.balanceOf(signers[2].address)).to.equal(2 * TCKO);
    })
});
