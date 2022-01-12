const expectRevert = require("@openzeppelin/test-helpers/src/expectRevert");
const { assert } = require("chai");

const TestErc20 = artifacts.require("./test/TestErc20.sol");
const TestErc721 = artifacts.require("./test/TestErc721.sol");
const TestWeth = artifacts.require("./test/TestWETH.sol"); 
const ERC721NFTMarket = artifacts.require("./ERC721NFTMarket.sol");

const dead = "0x000000000000000000000000000000000000dead";

const toWei = web3.utils.toWei;

contract("NftMarket", ([owner, buyer]) => {
    beforeEach(async () => {
        this.nft = await TestErc721.new();
        this.erc20 = await TestErc20.new()
        this.erc202 = await TestErc20.new()
        this.weth = await TestWeth.new();
        this.nftMarket = await ERC721NFTMarket.new(this.weth.address);

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
        ), "Ask: Price must be granter than zero")

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
        ), "Ask: Token not listed")

        await this.nftMarket.cancelAsk(
            this.nft.address,
            1000
        )

        assert.equal(await this.nft.ownerOf(1000),owner)
    })

    it ("buy", async () =>{
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
            {from: buyer}
        ), "Buy: Incorrect qoute token")

        await expectRevert(this.nftMarket.buy(
            this.nft.address,
            1000,
            this.erc20.address,
            500,
            {from: buyer}
        ), "Buy: Incorrect price")

        await expectRevert(this.nftMarket.buy(
            this.nft.address,
            1000,
            this.erc20.address,
            1001,
            {from: buyer}
        ), "Buy: Incorrect price")

        await this.nftMarket.buy(
            this.nft.address,
            1000,
            this.erc20.address,
            1000,
            {from: buyer}
        )

        assert.equal(await this.nft.ownerOf(1000), buyer);
        assert.equal(await this.erc20.balanceOf(owner), 1000);
    })

    it ("buy using eth", async () =>{
        await this.nftMarket.createAsk(
            this.nft.address,
            1000,
            this.weth.address,
            1
        )

        await this.nftMarket.buyUsingEth(
            this.nft.address,
            1000,
            {from: buyer, value: 1}
        )

        assert.equal(await this.nft.ownerOf(1000), buyer);
        assert.equal(await this.weth.balanceOf(owner), 1);
    });

    it("bid", async () => {
        await this.nftMarket.bid(
            this.nft.address,
            1000,
            this.erc20.address,
            1000,
            { from: buyer}
        );
        await expectRevert(
            this.nftMarket.bid(
                this.nft.address,
                1000,
                this.erc20.address,
                0,
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

        await this.nftMarket.acceptBid(
            this.nft.address,
            1000,
            buyer,
            this.erc20.address,
            1000,
        )

        assert.equal(await this.nft.ownerOf(1000), buyer);
        assert.equal(await this.erc20.balanceOf(owner), 1000);
    })

    it("bid using eth", async () => {
        await this.nftMarket.bidUsingEth(
            this.nft.address,
            1000,
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
})