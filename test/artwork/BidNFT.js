const BidArtworkNFT = artifacts.require("./artwork/BidArtworkNFT.sol");
const ArtworkNFT = artifacts.require("./artwork/ArtworkNFT.sol");
const TestErc20 = artifacts.require("./test/TestErc20.sol");
const { expectRevert } = require('@openzeppelin/test-helpers');

const dead = "0x000000000000000000000000000000000000dead";

contract("BidNFT", accounts => {
  beforeEach(async () => {
    this.erc20 = await TestErc20.new()
    this.nft = await ArtworkNFT.new("Demo", "DEMO", "0x000000000000000000000000000000000000dead", 5);
    this.bid = await BidArtworkNFT.new(this.nft.address, this.erc20.address, "0x000000000000000000000000000000000000dead", 5)

    await this.erc20.mint(101, {from: accounts[1]});
    await this.erc20.mint(100, {from: accounts[2]});

    await this.nft.mint(accounts[0], "", 10,{ value: 5});
    await this.nft.approve(this.bid.address, 1);
    await this.erc20.approve(this.bid.address, 1000, {from: accounts[1]});
  })

  it("sell token", async () => {
    await expectRevert(this.bid.readyToSellToken(2, 100), "owner query for nonexistent token")
    await expectRevert(this.bid.readyToSellToken(1, 100, {from: accounts[1]}), "Only Token Owner can sell token")
    await expectRevert(this.bid.readyToSellToken(1, 0), "Price must be granter than zero")
    await  this.bid.readyToSellToken(1, 100);

    await expectRevert(this.bid.cancelSellToken(1, {from: accounts[1]}), "caller is not the seller")
    await this.bid.cancelSellToken(1, {from: accounts[0]});
    await this.nft.approve(this.bid.address, 1);
    await  this.bid.readyToSellToken(1, 100);

    await expectRevert(this.bid.setCurrentPrice(1, 99, {from: accounts[1]}), "caller is not the seller");
    await expectRevert(this.bid.setCurrentPrice(1, 0, {from: accounts[0]}), "Price must be granter than zero");

    await this.bid.setCurrentPrice(1, 99, {from: accounts[0]})
    let currentPrice = await this.bid.prices(1);
    assert.equal(currentPrice.toString(), "99");
    await this.bid.setCurrentPrice(1, 100, {from: accounts[0]})


    await expectRevert(this.bid.buyToken(2, 100, {from: accounts[1]}), "Token not in sell book")    
    await expectRevert(this.bid.buyToken(1, 100, {from: accounts[5]}), "transfer amount exceeds balance")    
    await expectRevert(this.bid.buyToken(1, 99, {from: accounts[1]}), "invalid price")

    await this.bid.buyToken(1, 100, {from: accounts[1]})

    let bal = await this.erc20.balanceOf(accounts[0]);
    assert.equal(bal.toString(), 95)
    bal = await this.erc20.balanceOf(accounts[1]);
    assert.equal(bal.toString(), 1)


    // bid
    await this.nft.approve(this.bid.address, 1, {from: accounts[1]});
    await  this.bid.readyToSellToken(1, 100, {from: accounts[1]});

    await this.erc20.approve(this.bid.address, 1000, {from: accounts[2]});
    await expectRevert(this.bid.bidToken(1, 12121212, {from: accounts[2]}), "transfer amount exceeds balance")
    await this.bid.bidToken(1, 99, {from: accounts[2]});
    await this.bid.bidToken(1, 100, {from: accounts[2]});

    let bids = await this.bid.getBids(1);
    assert.equal(bids.length, 1)

    await this.bid.cancelBidToken(1, {from: accounts[2]})
    await expectRevert(this.bid.cancelBidToken(1, {from: accounts[2]}), "Bidder not found")
    bids = await this.bid.getBids(1);
    assert.equal(bids.length, 0)

    await this.bid.bidToken(1, 100, {from: accounts[2]});
    await this.bid.bidToken(1, 88, {from: accounts[2]});
    await this.bid.bidToken(1, 100, {from: accounts[2]});

    bal = await this.erc20.balanceOf(accounts[2]);
    assert.equal(bal.toString(), 0)

    await expectRevert(this.bid.sellTokenTo(1, accounts[2], 100, {from: accounts[0]}), "caller is not the seller")
    await expectRevert(this.bid.sellTokenTo(1, accounts[5], 100, {from: accounts[1]}), "bidder not found")
    await expectRevert(this.bid.sellTokenTo(1, accounts[2], 99, {from: accounts[1]}), "invalid price")
    await this.bid.sellTokenTo(1, accounts[2], 100, {from: accounts[1]});

    bal = await this.erc20.balanceOf(accounts[1]);
    assert.equal(bal.toString(), 86)

    bal = await this.erc20.balanceOf(accounts[0]);
    assert.equal(bal.toString(), 105)

    bal = await this.erc20.balanceOf(dead);
    assert.equal(bal.toString(), 10)
    
    bids = await this.bid.getBids(1);
    assert.equal(bids.length, 0)
  })

  it("setFeePercent", async () => {
    await expectRevert(this.bid.setFeePercent(10, {from: accounts[1]}), "caller is not the owner")
    await this.bid.setFeePercent(12, {from: accounts[0]})
  })

  it("setFeeAddress", async () => {
    await expectRevert(this.bid.setFeeAddress(accounts[1], {from: accounts[1]}), "caller is not the owner")
    await this.bid.setFeeAddress(accounts[1], {from: accounts[0]})
  })
})