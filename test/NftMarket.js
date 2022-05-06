const expectRevert = require("@openzeppelin/test-helpers/src/expectRevert");
const { assert } = require("chai");

const TestErc20 = artifacts.require("./test/TestErc20.sol");
const TestErc721 = artifacts.require("./test/TestErc721.sol");
const TestWeth = artifacts.require("./test/TestWETH.sol");
const ERC721NFTMarket = artifacts.require("./ERC721NFTMarket.sol");
const ERC721NFTSingleBundle = artifacts.require("./ERC721NFTSingleBundle.sol");

contract("NftMarket", ([owner, buyer, feeRecipient, RoyaltyFeeRecipient]) => {
  beforeEach(async () => {
    this.nft = await TestErc721.new();
    this.erc20 = await TestErc20.new();
    this.erc202 = await TestErc20.new();
    this.weth = await TestWeth.new();

    // protocol fee: 1%
    this.nftMarket = await ERC721NFTMarket.new(
      this.weth.address,
      feeRecipient,
      100
    );

    await this.nft.mint(1000);
    await this.erc20.mint(2000, { from: buyer });
    await this.erc202.mint(2000, { from: buyer });

    await this.nft.setApprovalForAll(this.nftMarket.address, true);
    await this.erc20.approve(this.nftMarket.address, 2000, { from: buyer });
    await this.erc202.approve(this.nftMarket.address, 2000, { from: buyer });

    this.bundle = await ERC721NFTSingleBundle.new(this.nft.address, "1", "!");
    await this.nft.mint(2);
    await this.nft.setApprovalForAll(this.bundle.address, true);
    await this.bundle.createBundle([2], "");
    await this.nftMarket.registerFingerPrintProxy(
      this.bundle.address,
      this.bundle.address
    );

    await this.bundle.setApprovalForAll(this.nftMarket.address, true);
  });

  it("create ask", async () => {
    await expectRevert(
      this.nftMarket.createAsk(this.nft.address, 1000, this.erc20.address, 0),
      "Ask: Price must be greater than zero"
    );

    await expectRevert(
      this.nftMarket.createAsk(this.nft.address, 1000, this.erc20.address, 10, {
        from: buyer,
      }),
      "ERC721: transfer of token that is not own"
    );

    await this.nftMarket.createAsk(
      this.nft.address,
      1000,
      this.erc20.address,
      1000
    );

    await expectRevert(
      this.nftMarket.cancelAsk(this.nft.address, 1000, { from: buyer }),
      "Ask: only seller"
    );

    await this.nftMarket.cancelAsk(this.nft.address, 1000);

    assert.equal(await this.nft.ownerOf(1000), owner);
  });

  it("buy", async () => {
    await expectRevert(
      this.nftMarket.buy(
        this.nft.address,
        1000,
        this.erc202.address,
        1000,
        "0x",
        { from: buyer }
      ),
      "token is not sell"
    );

    await this.nftMarket.createAsk(
      this.nft.address,
      1000,
      this.erc20.address,
      1000
    );

    await expectRevert(
      this.nftMarket.buy(
        this.nft.address,
        1000,
        this.erc202.address,
        1000,
        "0x",
        { from: buyer }
      ),
      "Buy: Incorrect qoute token"
    );

    await expectRevert(
      this.nftMarket.buy(
        this.nft.address,
        1000,
        this.erc20.address,
        500,
        "0x",
        { from: buyer }
      ),
      "Buy: Incorrect price"
    );

    await expectRevert(
      this.nftMarket.buy(
        this.nft.address,
        1000,
        this.erc20.address,
        1001,
        "0x",
        { from: buyer }
      ),
      "Buy: Incorrect price"
    );

    await this.nftMarket.buy(
      this.nft.address,
      1000,
      this.erc20.address,
      1000,
      "0x",
      { from: buyer }
    );

    assert.equal(await this.nft.ownerOf(1000), buyer);
    assert.equal(await this.erc20.balanceOf(owner), 990);
  });

  it("buy using eth", async () => {
    await expectRevert(
      this.nftMarket.buyUsingEth(this.nft.address, 1000, "0x", { from: buyer }),
      "token is not sell"
    );

    await this.nftMarket.createAsk(
      this.nft.address,
      1000,
      this.weth.address,
      1
    );

    await this.nftMarket.buyUsingEth(this.nft.address, 1000, "0x", {
      from: buyer,
      value: 1,
    });

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
      { from: buyer }
    );
    await expectRevert(
      this.nftMarket.createBid(
        this.nft.address,
        1000,
        this.erc20.address,
        0,
        "0x",
        { from: buyer }
      ),
      "Bid: Price must be granter than zero"
    );

    await expectRevert(
      this.nftMarket.acceptBid(
        this.nft.address,
        1000,
        buyer,
        this.erc20.address,
        2
      ),
      "AcceptBid: invalid price"
    );

    await expectRevert(
      this.nftMarket.acceptBid(
        this.nft.address,
        1000,
        buyer,
        this.erc20.address,
        1000,
        { from: buyer }
      ),
      "ERC721: transfer of token that is not own"
    );

    await expectRevert(
      this.nftMarket.acceptBid(
        this.nft.address,
        1000,
        buyer,
        this.erc202.address,
        1000
      ),
      "AcceptBid: invalid quoteToken"
    );

    const tx = await this.nftMarket.acceptBid(
      this.nft.address,
      1000,
      buyer,
      this.erc20.address,
      1000
    );
    assert.equal(await this.nft.ownerOf(1000), buyer);
    assert.equal(await this.erc20.balanceOf(owner), 990);
  });

  it("bid using eth", async () => {
    await this.nftMarket.createBidUsingEth(this.nft.address, 1000, "0x", {
      from: buyer,
      value: 1,
    });

    await this.nftMarket.acceptBid(
      this.nft.address,
      1000,
      buyer,
      this.weth.address,
      1
    );
    assert.equal(await this.nft.ownerOf(1000), buyer);
    assert.equal(await this.weth.balanceOf(owner), 1);
  });

  it("cancel bid", async () => {
    await this.nftMarket.createBid(
      this.nft.address,
      1000,
      this.erc20.address,
      1000,
      "0x",
      { from: buyer }
    );

    await this.nftMarket.cancelBid(this.nft.address, 1000, { from: buyer });

    await expectRevert(
      this.nftMarket.cancelBid(this.nft.address, 1000, { from: buyer }),
      "Bid: bid not found"
    );

    assert.equal(await this.erc20.balanceOf(buyer), 2000);
  });

  it("update bid", async () => {
    await this.nftMarket.createBid(
      this.nft.address,
      1000,
      this.erc20.address,
      500,
      "0x",
      { from: buyer }
    );

    await this.nftMarket.createBid(
      this.nft.address,
      1000,
      this.erc20.address,
      600,
      "0x",
      { from: buyer }
    );

    assert.equal(await this.erc20.balanceOf(buyer), 1400);
  });

  it("setProtocolFeePercent", async () => {
    await expectRevert(this.nftMarket.setProtocolFeePercent(501), "max_fee");
  });

  it("accept bid", async () => {
    await this.nftMarket.createAsk(
      this.nft.address,
      1000,
      this.erc20.address,
      100
    );

    await this.nftMarket.createBid(
      this.nft.address,
      1000,
      this.erc20.address,
      100,
      "0x",
      { from: buyer }
    );

    await expectRevert(
      this.nftMarket.acceptBid(
        this.nft.address,
        1000,
        buyer,
        this.erc20.address,
        100,
        { from: buyer }
      ),
      "ERC721: transfer of token that is not own"
    );

    await this.nftMarket.acceptBid(
      this.nft.address,
      1000,
      buyer,
      this.erc20.address,
      100
    );
    assert.equal(await this.erc20.balanceOf(owner), 99);
    assert.equal(await this.erc20.balanceOf(feeRecipient), 1);
    assert.equal(await this.erc20.balanceOf(buyer), 1900);
    assert.equal(await this.nft.ownerOf(1000), buyer);
  });

  it("Bid: verify fingerPrint  valid", async () => {
    await this.nftMarket.createBid(
      this.bundle.address,
      1,
      this.erc20.address,
      500,
      await this.bundle.getFingerprint(1),
      { from: buyer }
    );

    await await this.nftMarket.acceptBid(
      this.bundle.address,
      1,
      buyer,
      this.erc20.address,
      500
    );
  });

  it("Bid: verify fingerPrint invalid", async () => {
    await this.nftMarket.createBid(
      this.bundle.address,
      1,
      this.erc20.address,
      500,
      "0x",
      { from: buyer }
    );

    await expectRevert(
      this.nftMarket.acceptBid(
        this.bundle.address,
        1,
        buyer,
        this.erc20.address,
        500
      ),
      "Erc721Fingerprint: invalid fingerprint"
    );
  });

  it("Buy: verify fingerPrint  valid", async () => {
    await this.nftMarket.createAsk(
      this.bundle.address,
      1,
      this.erc20.address,
      1
    );

    await this.nftMarket.buy(
      this.bundle.address,
      1,
      this.erc20.address,
      1,
      await this.bundle.getFingerprint(1),
      { from: buyer }
    );
  });

  it("Buy: verify fingerPrint  INVALID", async () => {
    await this.nftMarket.createAsk(
      this.bundle.address,
      1,
      this.erc20.address,
      1
    );

    await expectRevert(
      this.nftMarket.buy(this.bundle.address, 1, this.erc20.address, 1, "0x", {
        from: buyer,
      }),
      "Erc721Fingerprint: invalid fingerprint"
    );
  });
});
