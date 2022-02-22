const { expectRevert } = require("@openzeppelin/test-helpers");
const { assert } = require("chai");
const TestErc20 = artifacts.require("./test/TestErc20.sol");
const ERC721NFTRent = artifacts.require("./ERC721NFTRent.sol");
const TestErc721 = artifacts.require("./test/TestErc721.sol");


contract("ERC721NFTBundle", ([owner, renter]) => {
    beforeEach(async () => {
        this.rent = await ERC721NFTRent.new();
        this.nft = await TestErc721.new();
        this.usdt = await TestErc20.new();

        await this.nft.mint(1);
        await this.nft.approve(this.rent.address, 1);

        await this.usdt.mint(100, {from: renter});
        await this.usdt.approve(this.rent.address, 100, {from: renter});
    })


    it("rent", async () => {
        await this.rent.lend(
            this.nft.address,
            1,
            this.usdt.address,
            100
        );

        await expectRevert(this.rent.rent(
            this.nft.address,
            1,
            60 * 60 * 24,
            this.nft.address,
            100,
            {from: renter}
        ), "ERC721NFTRent: invalid quoteToken")

        await expectRevert(this.rent.rent(
            this.nft.address,
            1,
            60 * 60 * 24,
            this.usdt.address,
            1010,
            {from: renter}
        ), "ERC721NFTRent: invalid pricePerDay")

        await expectRevert(this.rent.rent(
            this.nft.address,
            1,
            86300,
            this.usdt.address,
            100,
            {from: renter}
        ), "ERC721NFTRent: duration must be greater than 1 day")


        await this.rent.rent(
            this.nft.address,
            1,
            60 * 60 * 40,
            this.usdt.address,
            100,
            {from: renter}
        )

        assert.equal(await this.usdt.balanceOf(owner), 100);
        assert.equal(await this.usdt.balanceOf(renter), 0);

        const lend = await this.rent.lendings(this.nft.address, 1);
        assert.equal(lend[0], owner);
        assert.equal(lend[1], renter);


        await expectRevert(this.rent.rent(
            this.nft.address,
            1,
            60 * 60 * 24,
            this.usdt.address,
            100,
            {from: renter}
        ), "ERC721NFTRent: has renter")

        await expectRevert(this.rent.rent(
            this.nft.address,
            2,
            60 * 60 * 24,
            this.usdt.address,
            100,
            {from: renter}
        ), "ERC721NFTRent: not listed")
    })

    it("cancel lend", async () => {
        await this.rent.lend(
            this.nft.address,
            1,
            this.usdt.address,
            100
        );

        await expectRevert(this.rent.cancelLend(
            this.nft.address,
            1,
            {from: renter}
        ), "ERC721NFTRent:only lender")


        await this.rent.cancelLend(
            this.nft.address,
            1,
        )
        
        assert.equal(await this.nft.ownerOf(1), owner);
    })


    it("cancel lend expired", async () => {
        await this.rent.lend(
            this.nft.address,
            1,
            this.usdt.address,
            100
        );

        await this.rent.rent(
            this.nft.address,
            1,
            60 * 60 * 24,
            this.usdt.address,
            100,
            {from: renter}
        )


        await expectRevert(this.rent.cancelLend(
            this.nft.address,
            1,
        ), "ERC721NFTRent: not expired")

        const time = await getLastBlockTimestamp()

        await mineBlockWithTS(time * 60 * 60 * 25);

        await this.rent.cancelLend(
            this.nft.address,
            1,
        )
        assert.equal(await this.nft.ownerOf(1), owner);
    } )
    
})



async function getLastBlockTimestamp() {
    return (await web3.eth.getBlock(await web3.eth.getBlockNumber())).timestamp;
}



async function mineBlockWithTS(ts) {
    await web3.currentProvider.send({
        jsonrpc: '2.0',
        method: 'evm_mine',
        params: [ts],
    }, () => {});

    await setChainTimestamp(ts);
}



async function setChainTimestamp(ts) {
    await web3.currentProvider.send({
        jsonrpc: '2.0',
        method: 'evm_setTimestamp',
        params: [ ts ],
    }, () => {});
    // for unknown reason, omitting the second parameter (callback) fails in my environment
}
