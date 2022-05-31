const { expect } = require("chai");
const { ethers } = require("hardhat");

const MILLION = ethers.BigNumber.from("1000000");

async function gas(tx) {
    const receipt = await tx.wait();
    console.log("Gas: " + receipt.cumulativeGasUsed.toString());
}

describe("Minting, distribution and unlocking", function () {
    it("Should complete all rounds", async function () {
        const signers = await ethers.getSigners();

        const DAOKasasi = await ethers.getContractFactory("MockDAOKasasi");
        const KilitliTCKO = await ethers.getContractFactory("KilitliTCKO");
        const daoKasasi = await DAOKasasi.deploy();
        console.log("DAO_KASASI:   " + daoKasasi.address);

        const TCKO = await ethers.getContractFactory("TCKO");
        const tcko = await TCKO.deploy();
        await tcko.deployed();

        const tckok = KilitliTCKO.attach(await tcko.kilitliTCKO());

        console.log("TCKO:         " + tcko.address);
        console.log("KILITLI_TCKO: " + tckok.address);

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

        await mintAll(MILLION);
        const tckoSupply = await tcko.totalSupply();
        const tckoCap = await tcko.supplyCap();
        const tckokSupply = await tckok.totalSupply();

        expect(tckoSupply).to.equal(20 * MILLION * MILLION);
        expect(3 * (tckoSupply - tckokSupply)).to.equal(tckokSupply);

        const twoFiddy = ethers.BigNumber.from("250000");
        await tcko.connect(signers[1]).transfer(signers[2].address, twoFiddy * MILLION);

        expect(await tcko.balanceOf(signers[1].address)).to.equal(0);
        expect(await tcko.balanceOf(signers[2].address)).to.equal(2 * twoFiddy * MILLION);

        await tcko.incrementDistroStage(1); // Presale2

        await mintAll(MILLION);
        expect(await tcko.totalSupply()).to.equal(40 * MILLION * MILLION);
        expect(await tckok.totalSupply()).to.equal(30 * MILLION * MILLION);

        await tcko.incrementDistroStage(2); // DAOSaleStart

        expect(await tcko.totalSupply()).to.equal(60 * MILLION * MILLION);
        expect(await tckok.totalSupply()).to.equal(30 * MILLION * MILLION);

        await tcko.incrementDistroStage(3); // DAOSaleEnd

        await tckok.unlock(signers[1].address);
        await tckok.unlock(signers[2].address);

        expect(await tcko.balanceOf(signers[1].address)).to.equal(MILLION * MILLION);
        expect(await tcko.balanceOf(signers[2].address)).to.equal(6 * twoFiddy * MILLION);

        await tckok.unlockAllEven();

        expect(await tckok.balanceOf(signers[1].address)).to.equal(3 * twoFiddy * MILLION);
        expect(await tckok.balanceOf(signers[2].address)).to.equal(3 * twoFiddy * MILLION);

        await tcko.incrementDistroStage(4); // DAOAMMStart

        expect(await tcko.totalSupply()).to.equal(80 * MILLION * MILLION);
        expect(await tckok.totalSupply()).to.equal(15 * MILLION * MILLION);

        await tcko.incrementDistroStage(5); // Presale2Unlock

        gas(await tckok.unlockAllOdd());

        await tcko.incrementDistroStage(6); // FinalMint

        await mintAll(MILLION);
        await tckok.unlock(signers[1].address);

        expect(await tckok.balanceOf(signers[1].address)).to.equal(3 * twoFiddy * MILLION);

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
