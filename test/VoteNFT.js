const ArtworkNFT = artifacts.require("./artwork/ArtworkNFT.sol");
const VoteNFT = artifacts.require("./VoteNFT.sol");
const TestErc20 = artifacts.require("./test/TestErc20.sol");
const { expectRevert } = require('@openzeppelin/test-helpers');

const dead = "0x000000000000000000000000000000000000dead";

const toWei = web3.utils.toWei;

contract("VoteNFT", ([owner, voter]) => {
    beforeEach(async () => {
        this.nft = await ArtworkNFT.new("Demo", "DEMO", dead, 5);
        this.erc20 = await TestErc20.new()
        this.vote = await VoteNFT.new(this.erc20.address, dead);

        await this.nft.mint(owner, "", 5, {value: 5});

        // mint token for voter
        await this.erc20.mint(toWei("100", "ether"), {from: voter})
        await this.erc20.approve(this.vote.address, toWei("80", "ether"), {from: voter});
    })

    it("vote", async () => {
        await expectRevert(this.vote.vote(this.nft.address, 2, owner, toWei("5", "ether"), { from: voter}), "owner query for nonexistent token")
        await expectRevert(this.vote.vote(this.nft.address, 1, owner, toWei("100", "ether"), { from: voter}), "transfer amount exceeds allowance")
        await expectRevert(this.vote.vote(this.nft.address, 1, owner, toWei("0.9", "ether"), { from: voter}), "min vote");
        await this.vote.vote(this.nft.address, 1, owner, toWei("80", "ether"), { from: voter})
        await expectRevert(this.vote.vote(this.nft.address, 1, owner, toWei("50", "ether"), { from: voter}), "transfer amount exceeds balance")

        let bal = await this.erc20.balanceOf(owner);
        assert.equal(bal.toString(), toWei("40", "ether"))
        bal = await this.erc20.balanceOf(dead);
        assert.equal(bal.toString(), toWei("40", "ether"))
    })

    it("setFeeAddress", async() => {
        await expectRevert(this.vote.setFeeAddress(voter, {from: voter}), "caller is not the owner")
    })
})