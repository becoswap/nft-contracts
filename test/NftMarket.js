const expectRevert = require("@openzeppelin/test-helpers/src/expectRevert");
const { assert } = require("chai");

const TestErc20 = artifacts.require("./test/TestErc20.sol");
const TestErc721 = artifacts.require("./test/TestErc721.sol");
const TestWeth = artifacts.require("./test/TestWETH.sol"); 
const ERC721NFTMarket = artifacts.require("./ERC721NFTMarket.sol");
const FeeProvider = artifacts.require("./FeeProvider.sol");



contract("NftMarket", ([owner, buyer, feeRecipient, RoyaltyFeeRecipient]) => {
    beforeEach(async () => {
        this.nft = await TestErc721.new();
        this.erc20 = await TestErc20.new()
        this.erc202 = await TestErc20.new()
        this.weth = await TestWeth.new();
        this.feeProvider = await FeeProvider.new();

        // protocol fee: 1%
        this.nftMarket = await ERC721NFTMarket.new(this.weth.address, this.feeProvider.address, feeRecipient, 100);

        await this.nft.mint(1000);
        await this.erc20.mint(2000, { from: buyer});
        await this.erc202.mint(2000, { from: buyer});
        
        await this.nft.approve(this.nftMarket.address, 1000);
        await this.erc20.approve(this.nftMarket.address, 2000, { from: buyer});
        await this.erc202.approve(this.nftMarket.address, 2000, { from: buyer});
    })

    it ("create ask", async () =>{
        await expectRevert(this.nftMarket.createAsk(
            this.nft.address,
            1000,
            this.erc20.address,
            0
        ), "Ask: Price must be greater than zero")

        await expectRevert(this.nftMarket.createAsk(
            this.nft.address,
            1000,
            this.erc20.address,
            10, { from: buyer}
        ), "ERC721: transfer of token that is not own")


        await this.nftMarket.createAsk(
            this.nft.address,
            1000,
            this.erc20.address,
            1000
        )

        await expectRevert(this.nftMarket.cancelAsk(
            this.nft.address,
            1000,
            { from: buyer}
        ), "Ask: only seller")

        await this.nftMarket.cancelAsk(
            this.nft.address,
            1000
        )

        assert.equal(await this.nft.ownerOf(1000),owner)
    })

    it ("buy", async () =>{
        await expectRevert(this.nftMarket.buy(
            this.nft.address,
            1000,
            this.erc202.address,
            1000,
            "0x",
            {from: buyer}
        ), "token is not sell")


        await this.nftMarket.createAsk(
            this.nft.address,
            1000,
            this.erc20.address,
            1000
        )

        await expectRevert(this.nftMarket.buy(
            this.nft.address,
            1000,
            this.erc202.address,
            1000,
            "0x",
            {from: buyer}
        ), "Buy: Incorrect qoute token")

        await expectRevert(this.nftMarket.buy(
            this.nft.address,
            1000,
            this.erc20.address,
            500,
            "0x",
            {from: buyer}
        ), "Buy: Incorrect price")

        await expectRevert(this.nftMarket.buy(
            this.nft.address,
            1000,
            this.erc20.address,
            1001,
            "0x",
            {from: buyer}
        ), "Buy: Incorrect price")

        await this.nftMarket.buy(
            this.nft.address,
            1000,
            this.erc20.address,
            1000,
            "0x",
            {from: buyer}
        )

        assert.equal(await this.nft.ownerOf(1000), buyer);
        assert.equal(await this.erc20.balanceOf(owner), 990);
    })

    it ("buy using eth", async () =>{
        await expectRevert(this.nftMarket.buyUsingEth(
            this.nft.address,
            1000,
            "0x",
            {from: buyer}
        ), "token is not sell")

        await this.nftMarket.createAsk(
            this.nft.address,
            1000,
            this.weth.address,
            1
        )

        await this.nftMarket.buyUsingEth(
            this.nft.address,
            1000,
            "0x",
            {from: buyer, value: 1}
        )

        assert.equal(await this.nft.ownerOf(1000), buyer);
        assert.equal(await this.weth.balanceOf(owner), 1);
    });

    it("bid", async () => {
        await this.nftMarket.createBid(
            this.nft.address,
            1000,
            this.erc20.address,
            1000,
            "0x",
            { from: buyer}
        );
        await expectRevert(
            this.nftMarket.createBid(
                this.nft.address,
                1000,
                this.erc20.address,
                0,
                "0x",
                { from: buyer}
            ),
             "Bid: Price must be granter than zero"
        )

        await expectRevert(this.nftMarket.acceptBid(
            this.nft.address,
            1000,
            buyer,
            this.erc20.address,
            2,
        ), "AcceptBid: invalid price");

        await expectRevert(this.nftMarket.acceptBid(
            this.nft.address,
            1000,
            buyer,
            this.erc20.address,
            1000,
            {from: buyer}
        ), "ERC721: transfer of token that is not own");

        await expectRevert(this.nftMarket.acceptBid(
            this.nft.address,
            1000,
            buyer,
            this.erc202.address,
            1000,
        ), "AcceptBid: invalid quoteToken");

        const tx = await this.nftMarket.acceptBid(
            this.nft.address,
            1000,
            buyer,
            this.erc20.address,
            1000,
        )
        assert.equal(await this.nft.ownerOf(1000), buyer);
        assert.equal(await this.erc20.balanceOf(owner), 990);
    })

    it("bid using eth", async () => {
        await this.nftMarket.createBidUsingEth(
            this.nft.address,
            1000,
            "0x",
            { from: buyer, value: 1}
        );

        await this.nftMarket.acceptBid(
            this.nft.address,
            1000,
            buyer,
            this.weth.address,
            1,
        )
        assert.equal(await this.nft.ownerOf(1000), buyer);
        assert.equal(await this.weth.balanceOf(owner), 1);
    })

    it ("cancel bid", async () => {
        await this.nftMarket.createBid(
            this.nft.address,
            1000,
            this.erc20.address,
            1000,
            "0x",
            { from: buyer}
        );

        await this.nftMarket.cancelBid(
            this.nft.address,
            1000,
            { from: buyer}
        );

        await expectRevert(
            this.nftMarket.cancelBid(
                this.nft.address,
                1000,
                { from: buyer}
            ), "Bid: bid not found"
        )

        assert.equal(await this.erc20.balanceOf(buyer), 2000);
    })

    it ("update bid", async () => {
        await this.nftMarket.createBid(
            this.nft.address,
            1000,
            this.erc20.address,
            500,
            "0x",
            { from: buyer}
        );

        await this.nftMarket.createBid(
            this.nft.address,
            1000,
            this.erc20.address,
            600,
            "0x",
            { from: buyer}
        );

        assert.equal(await this.erc20.balanceOf(buyer), 1400);
    })

    it("Royalty fee", async () => {
        await this.feeProvider.setRecipient(
            this.nft.address,
            [RoyaltyFeeRecipient],
            [100]
        )

        await this.nftMarket.createBid(
            this.nft.address,
            1000,
            this.erc20.address,
            100,
            "0x",
            { from: buyer}
        );
        await this.nftMarket.acceptBid(
            this.nft.address,
            1000,
            buyer,
            this.erc20.address,
            100,
        )

        assert.equal(await this.erc20.balanceOf(owner), 98);
        assert.equal(await this.erc20.balanceOf(feeRecipient), 1);
        assert.equal(await this.erc20.balanceOf(RoyaltyFeeRecipient), 1);
    })

    it("setProtocolFeePercent", async () => {
        await expectRevert(
            this.nftMarket.setProtocolFeePercent(501),
            "max_fee"
        );
    })

    it("accept bid", async () => {
        await this.nftMarket.createAsk(
            this.nft.address,
            1000,
            this.erc20.address,
            100
        )

        await this.nftMarket.createBid(
            this.nft.address,
            1000,
            this.erc20.address,
            100,
            "0x",
            { from: buyer}
        )

        await expectRevert(this.nftMarket.acceptBid(
            this.nft.address,
            1000,
            buyer,
            this.erc20.address,
            100,
            {from: buyer}
        ), "ERC721: transfer of token that is not own")

        await this.nftMarket.acceptBid(
            this.nft.address,
            1000,
            buyer,
            this.erc20.address,
            100,
        )
        assert.equal(await this.erc20.balanceOf(owner), 99);
        assert.equal(await this.erc20.balanceOf(feeRecipient), 1);
        assert.equal(await this.erc20.balanceOf(buyer), 1900);
        assert.equal(await this.nft.ownerOf(1000),  buyer);
    })
})