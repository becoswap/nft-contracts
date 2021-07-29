const BidNFT = artifacts.require("./artwork/BidNFT.sol");
const ArtworkNFT = artifacts.require("./artwork/ArtworkNFT.sol");
const TestErc20 = artifacts.require("./test/TestErc20.sol");
const { expectRevert } = require('@openzeppelin/test-helpers');

const dead = "0x000000000000000000000000000000000000dead";

contract("BidNFT", accounts => {



  it("sell", async () => {
    const erc20 = await TestErc20.deployed();
    await erc20.mint(101, {from: accounts[1]});
    await erc20.mint(100, {from: accounts[2]});

    const artworkNFT = await ArtworkNFT.deployed();
    await artworkNFT.mint(accounts[0], "", 10,{ value: 5});
    const bidNft = await BidNFT.deployed();
    await artworkNFT.approve(bidNft.address, 1);
    await erc20.approve(bidNft.address, 1000, {from: accounts[1]});

    await expectRevert(bidNft.readyToSellToken(2, 100), "owner query for nonexistent token")
    await expectRevert(bidNft.readyToSellToken(1, 100, {from: accounts[1]}), "Only Token Owner can sell token")
    await expectRevert(bidNft.readyToSellToken(1, 0), "Price must be granter than zero")
    await  bidNft.readyToSellToken(1, 100);

    await expectRevert(bidNft.buyToken(2, {from: accounts[1]}), "Token not in sell book")    
    await expectRevert(bidNft.buyToken(1, {from: accounts[5]}), "transfer amount exceeds balance")    
    await bidNft.buyToken(1, {from: accounts[1]})

    let bal = await erc20.balanceOf(accounts[0]);
    assert.equal(bal.toString(), 95)
    bal = await erc20.balanceOf(accounts[1]);
    assert.equal(bal.toString(), 1)


    // bid
    await artworkNFT.approve(bidNft.address, 1, {from: accounts[1]});
    await  bidNft.readyToSellToken(1, 100, {from: accounts[1]});

    await erc20.approve(bidNft.address, 1000, {from: accounts[2]});
    await expectRevert(bidNft.bidToken(1, 12121212, {from: accounts[2]}), "transfer amount exceeds balance")
    await bidNft.bidToken(1, 99, {from: accounts[2]});
    await bidNft.bidToken(1, 100, {from: accounts[2]});

    let bids = await bidNft.getBids(1);
    assert.equal(bids.length, 1)

    await bidNft.cancelBidToken(1, {from: accounts[2]})
    await expectRevert(bidNft.cancelBidToken(1, {from: accounts[2]}), "Bidder not found")
    bids = await bidNft.getBids(1);
    assert.equal(bids.length, 0)

    await bidNft.bidToken(1, 100, {from: accounts[2]});

    bal = await erc20.balanceOf(accounts[2]);
    assert.equal(bal.toString(), 0)

    await bidNft.sellTokenTo(1, accounts[2]);
    bal = await erc20.balanceOf(accounts[1]);
    assert.equal(bal.toString(), 86)

    bal = await erc20.balanceOf(accounts[0]);
    assert.equal(bal.toString(), 105)

    bal = await erc20.balanceOf(dead);
    assert.equal(bal.toString(), 10)
    
    bids = await bidNft.getBids(1);
    assert.equal(bids.length, 0)
  })
})