const { expectRevert } = require("@openzeppelin/test-helpers");
const { assert } = require("chai");

const ERC721NFTLaunchPad = artifacts.require("./ERC721NFTLaunchPad.sol");
const TestErc20 = artifacts.require("./test/TestErc20.sol");
const TestStakePool = artifacts.require("./test/TestStakePool.sol");
const TestLaunchPadMinter = artifacts.require("./test/TestLaunchPadMinter.sol");



contract("NFTLaunchPad", ([owner, treasury, user1]) => {
    beforeEach(async () => {
        this.usdt = await TestErc20.new();
        this.stakePool = await TestStakePool.new();
        this.launchPadMinter = await TestLaunchPadMinter.new();
        this.launchpad = await ERC721NFTLaunchPad.new(this.stakePool.address, this.launchPadMinter.address, treasury, this.usdt.address);

        await this.usdt.mint(100, {from: user1})
        await this.usdt.approve(this.launchpad.address, 100, {from: user1});
        
    })
    
    it ("buy", async () => {
        await this.launchpad.addLaunch(50, 2, 1, 80);
        await this.launchpad.buy(0, {from: user1});
        await this.launchpad.buy(0, {from: user1});
        await expectRevert(this.launchpad.buy(0, {from: user1}), "ERC721NFTLaunchPad: max can buy");

        assert.equal(await this.usdt.balanceOf(treasury), 100);
        assert.equal(await this.launchPadMinter.levels(user1, 1), 1);
    })

    it ("buy: sold out", async () => {
        await this.launchpad.addLaunch(50, 2, 1, 30);
        await this.launchpad.buy(0, {from: user1});
        await this.launchpad.buy(0, {from: user1});
        await expectRevert(this.launchpad.buy(0, {from: user1}), "ERC721NFTLaunchPad: sold out");
    })

    it ("buy: sold out", async () => {
        await expectRevert(this.launchpad.buy(0, {from: user1}), "ERC721NFTLaunchPad: Launch not found");
    })
})