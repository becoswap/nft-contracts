const expectRevert = require("@openzeppelin/test-helpers/src/expectRevert");
const { assert } = require("chai");
const ERC1155NFTMarket = artifacts.require("./ERC1155NFTMarket.sol");
const TestErc1155 = artifacts.require("./TestErc1155.sol");
const TestErc20 = artifacts.require("./test/TestErc20.sol");
const TestWeth = artifacts.require("./test/TestWETH.sol"); 



contract("ERC1155NFTMarket", ([owner, buyer, feeRecipient]) => {
    beforeEach(async () => {
        this.nft = await TestErc1155.new();
        this.usd = await TestErc20.new()
        this.weth = await TestWeth.new();
        this.market = await ERC1155NFTMarket.new(feeRecipient, 250);

        await this.nft.mint(1, 100);
        await this.nft.setApprovalForAll(this.market.address, true);

        await this.usd.mint(2000, { from: buyer });
        await this.usd.approve(this.market.address, 2000, { from: buyer});
    })

    it("Ask", async () => {
        await expectRevert(
            this.market.createAsk(
                this.nft.address,
                1,
                0,
                this.usd.address,
                100
            ),
            "ERC1155NFTMarket: _quantity must be greater than zero"
        )

        await expectRevert(
            this.market.createAsk(
                this.nft.address,
                1,
                1,
                this.usd.address,
                0
            ),
            "ERC1155NFTMarket: _pricePerUnit must be greater than zero"
        )

        await this.market.createAsk(
            this.nft.address,
            1,
            100,
            this.usd.address,
            100
        )

        await expectRevert(
            this.market.createAsk(
                this.nft.address,
                1,
                1,
                this.usd.address,
                1
            ),
            "ERC1155: insufficient balance for transfer"
        )
    })

    it("Cancel ask", async () => {
        await this.market.createAsk(
            this.nft.address,
            1,
            100,
            this.usd.address,
            100
        )

        assert.equal(await this.nft.balanceOf(owner, 1), 0)
        await this.market.cancelAsk(1);
        assert.equal(await this.nft.balanceOf(owner, 1), 100)

        await expectRevert(
            this.market.cancelAsk(1),
            "ERC1155NFTMarket: only seller"
        )
    })

    it("Cancel ASK: buy 1", async () => {
        await this.market.createAsk(
            this.nft.address,
            1,
            100,
            this.usd.address,
            100
        )

        await this.market.buy(
            1,
            1,
            {from: buyer}
        )

        await this.market.cancelAsk(1);
        assert.equal(await this.nft.balanceOf(owner, 1), 99)
    })

    it ("Buy", async () => {
        await this.market.createAsk(
            this.nft.address,
            1,
            2,
            this.usd.address,
            100
        )

        await expectRevert(
            this.market.buy(
                1,
                0,
                {from: buyer}
            ),
            "ERC1155NFTMarket: quantity must be greater than zero"
        )

        await this.market.buy(
            1,
            1,
            {from: buyer}
        )

        await expectRevert(
            this.market.buy(
                1,
                100,
                {from: buyer}
            ),
            "ERC1155NFTMarket: quantity is not enought"
        )

        assert.equal(await this.usd.balanceOf(owner), 98);
        assert.equal(await this.usd.balanceOf(buyer), 1900);
        assert.equal((await this.nft.balanceOf(buyer, 1)), 1);
        let ask = await this.market.asks(1);
        assert.equal(ask[3], 1);
    })

    it("Offer", async () => {
        await expectRevert(
            this.market.createOffer(
                this.nft.address,
                1,
                2,
                this.usd.address,
                0,
                {from: buyer}
            ),
            "ERC1155NFTMarket: _pricePerUnit must be greater than zero"
        )
        await expectRevert(
            this.market.createOffer(
                this.nft.address,
                1,
                0,
                this.usd.address,
                1,
                {from: buyer}
            ),
            "ERC1155NFTMarket: _quantity must be greater than zero"
        )

        await this.market.createOffer(
            this.nft.address,
            1,
            2,
            this.usd.address,
            100,
            {from: buyer}
        )
        
        await this.market.acceptOffer(1, 1);
        
        await expectRevert(
            this.market.acceptOffer(1, 111),
            "ERC1155NFTMarket: quantity is not enought"
        )

        await expectRevert(
            this.market.acceptOffer(1, 0),
            "ERC1155NFTMarket: quantity must be greater than zero"
        )

        assert.equal((await this.nft.balanceOf(buyer, 1)), 1);
        assert.equal(await this.usd.balanceOf(owner), 98);
        assert.equal(await this.usd.balanceOf(buyer), 1800);

        await this.market.cancelOffer(1, {from: buyer});
        assert.equal(await this.usd.balanceOf(buyer), 1900);

        await expectRevert(
            this.market.cancelOffer(
                1,
                {from: buyer}
            ),
            "RC1155NFTMarket: only offer owner"
        )
    })

    it("Accept Offer all", async () => {
        await this.market.createOffer(
            this.nft.address,
            1,
            2,
            this.usd.address,
            100,
            {from: buyer}
        )

        await this.market.acceptOffer(1, 2);
        let offer = await this.market.offers(1);
        assert.equal(offer[0], "0x0000000000000000000000000000000000000000")
    })

    it("Buy all", async () => {
        await this.market.createAsk(
            this.nft.address,
            1,
            2,
            this.usd.address,
            100
        )
        await this.market.buy(1,2, {from: buyer});
        let ask = await this.market.asks(1);
        assert.equal(ask[0], "0x0000000000000000000000000000000000000000")
    })
})