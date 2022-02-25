const expectRevert = require("@openzeppelin/test-helpers/src/expectRevert");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { assert } = require("chai");

const TestErc20 = artifacts.require("./test/TestErc20.sol");
const TestErc721 = artifacts.require("./test/TestErc721.sol");
const TestWeth = artifacts.require("./test/TestWETH.sol"); 
const ERC721NFTAuction = artifacts.require("./ERC721NFTAuction.sol");
const FeeProvider = artifacts.require("./FeeProvider.sol");

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


contract("NFTAuction", ([owner, buyer, buyer1, feeRecipient, RoyaltyFeeRecipient]) => {
    beforeEach(async () => {
        this.nft = await TestErc721.new();
        this.usdt = await TestErc20.new()
        this.beco = await TestErc20.new()
        this.weth = await TestWeth.new();
        this.feeProvider = await FeeProvider.new();
        this.nftAuction = await ERC721NFTAuction.new(this.weth.address, this.feeProvider.address, feeRecipient, 100);

        await this.nft.mint(1000);
        await this.usdt.mint(2000, { from: buyer});
        await this.usdt.mint(50, { from: buyer1});
        await this.beco.mint(2000, { from: buyer});
        
        await this.nft.approve(this.nftAuction.address, 1000);
        await this.usdt.approve(this.nftAuction.address, 2000, { from: buyer});
        await this.usdt.approve(this.nftAuction.address, 2000, { from: buyer1});
        await this.beco.approve(this.nftAuction.address, 2000, { from: buyer});
    })

    it("Auction", async () => {
        const time = await getLastBlockTimestamp();

        await expectRevert(
            this.nftAuction.createAuction(
                this.nft.address,
                1000,
                this.usdt.address,
                0,
                0,
                1
            ), "ERC721NFTAuction: _endTime must be greater than block.timestamp"
        )

        await expectRevert(
            this.nftAuction.createAuction(
                this.nft.address,
                1000,
                this.usdt.address,
                0,
                time  + 200,
                time  + 100
            ), "ERC721NFTAuction: _endTime must be greater than _startTime"
        )

        await this.nftAuction.createAuction(
            this.nft.address,
            1000,
            this.usdt.address,
            1,
            time + 200,
            time  + 1000
        )

        await expectRevert( 
            this.nftAuction.bid(
                this.nft.address,
                1000,
                this.usdt.address,
                100,
                { from: buyer}
            ), "ERC721NFTAuction: auction not started"
        )
        

        
        await expectRevert( 
            this.nftAuction.createAuction(
                this.nft.address,
                1000,
                this.usdt.address,
                0,
                time + 100,
                time  + 1000
            ), "ERC721: transfer of token that is not own"
        )
        
        

        await mineBlockWithTS(time +200)

        await expectRevert( 
            this.nftAuction.bid(
                this.nft.address,
                10001,
                this.usdt.address,
                100,
                { from: buyer}
            ), "ERC721NFTAuction: auction not found"
        )

        await expectRevert( 
            this.nftAuction.bid(
                this.nft.address,
                1000,
                this.usdt.address,
                0,
                { from: buyer}
            ), "ERC721NFTAuction: price must be greater than or equal bidPrice"
        )

        await expectRevert( 
            this.nftAuction.bid(
                this.nft.address,
                1000,
                this.beco.address,
                1,
                { from: buyer}
            ), "ERC721NFTAuction: invalid quote token"
        )

        await this.nftAuction.bid(
            this.nft.address,
            1000,
            this.usdt.address,
            50,
            { from: buyer1}
        )

        await expectRevert( 
            this.nftAuction.bid(
                this.nft.address,
                1000,
                this.beco.address,
                50,
                { from: buyer}
            ), "price must be greater than bidPrice with minBidIncrementPercentage"
        )

        assert.equal(await this.usdt.balanceOf(buyer1), 0)
        
        await this.nftAuction.bid(
            this.nft.address,
            1000,
            this.usdt.address,
            100,
            { from: buyer}
        )
        assert.equal((await this.usdt.balanceOf(buyer1)).toString(), 50)

        await expectRevert(
            this.nftAuction.collect(
                this.nft.address,
                1000,
            ), "ERC721NFTAuction: auction not end"
        )

        await mineBlockWithTS(time +1100)
        
        await expectRevert( 
            this.nftAuction.bid(
                this.nft.address,
                1000,
                this.usdt.address,
                100,
                { from: buyer}
            ), "ERC721NFTAuction: auction ended"
        )

        await this.nftAuction.collect(
            this.nft.address,
            1000,
            { from: buyer}
        )

        assert.equal(await this.nft.ownerOf(1000),buyer)
        assert.equal(await this.usdt.balanceOf(owner), 99)
    })

    it("Cancel Auction", async () => {
        const time = await getLastBlockTimestamp();
        await this.nftAuction.createAuction(
            this.nft.address,
            1000,
            this.usdt.address,
            0,
            time + 100,
            time  + 1000
        )
        
        await expectRevert(
            this.nftAuction.cancelAuction(
                this.nft.address,
                1000,
                { from: buyer}
            ), "ERC721NFTAuction: only seller"
        )

        await this.nftAuction.cancelAuction(
            this.nft.address,
            1000,
        )

        await this.nft.approve(this.nftAuction.address, 1000);
        await this.nftAuction.createAuction(
            this.nft.address,
            1000,
            this.usdt.address,
            0,
            0,
            time  + 1000
        )

        await this.nftAuction.bid(
            this.nft.address,
            1000,
            this.usdt.address,
            99,
            { from: buyer}
        )

        await expectRevert(
            this.nftAuction.cancelAuction(
                this.nft.address,
                1000,
            ), "ERC721NFTAuction: has bidder"
        )

    })

    it ("Auction with eth", async () => {
        const time = await getLastBlockTimestamp();
        await this.nftAuction.createAuction(
            this.nft.address,
            1000,
            this.weth.address,
            0,
            0,
            time  + 1000
        )

        await this.nftAuction.bid(
            this.nft.address,
            1000,
            this.weth.address,
            1,
            { from: buyer1, value: 1}
        )

        await this.nftAuction.bid(
            this.nft.address,
            1000,
            this.weth.address,
            2,
            { from: buyer, value: 2}
        )

    })

    it ("Only Owner", async () => {
        await expectRevert(this.nftAuction.setFeeProvider(this.nft.address, {from: buyer}), "Ownable: caller is not the owner")
        await expectRevert(this.nftAuction.setProtocolFeeRecipient(this.nft.address, {from: buyer}), "Ownable: caller is not the owner")
        await expectRevert(this.nftAuction.setProtocolFeePercent(10, {from: buyer}), "Ownable: caller is not the owner")
    })

    it("Royalty fee", async () => {
        await this.feeProvider.setRecipient(
            this.nft.address,
            [RoyaltyFeeRecipient],
            [100]
        )

        const time = await getLastBlockTimestamp();
        await this.nftAuction.createAuction(
            this.nft.address,
            1000,
            this.usdt.address,
            0,
            0,
            time  + 1000
        )
        
        await this.nftAuction.bid(
            this.nft.address,
            1000,
            this.usdt.address,
            100,
            { from: buyer}
        )

        await mineBlockWithTS(time +1100)

        await this.nftAuction.collect(
            this.nft.address,
            1000,
            { from: buyer}
        )
        
        assert.equal(await this.usdt.balanceOf(owner), 98) // seller: 98%
        assert.equal(await this.usdt.balanceOf(RoyaltyFeeRecipient), 1) //  Royalty: 1%
        assert.equal(await this.usdt.balanceOf(feeRecipient), 1) // protocol fee: 1%
    })
})