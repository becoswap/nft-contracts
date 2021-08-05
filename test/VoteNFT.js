const ArtworkNFT = artifacts.require("./artwork/ArtworkNFT.sol");
const VoteNFT = artifacts.require("./VoteNFT.sol");
const TestErc20 = artifacts.require("./test/TestErc20.sol");
const { expectRevert } = require('@openzeppelin/test-helpers');

const dead = "0x000000000000000000000000000000000000dead";


contract("VoteNFT", ([owner, voter]) => {
    beforeEach(async () => {
        this.nft = await ArtworkNFT.new("Demo", "DEMO", dead, 5);
        this.erc20 = await TestErc20.new()
        this.vote = await VoteNFT.new(this.erc20.address, dead);

        await this.nft.mint(owner, "", 5, {value: 5});

        // mint token for voter
        await this.erc20.mint(100, {from: voter})
        await this.erc20.approve(this.vote.address, 80, {from: voter});
    })

    it("vote", async () => {
        await expectRevert(this.vote.vote(this.nft.address, 2, 100, { from: voter}), "owner query for nonexistent token")
        await expectRevert(this.vote.vote(this.nft.address, 1, 100, { from: voter}), "transfer amount exceeds allowance")
        await this.vote.vote(this.nft.address, 1, 80, { from: voter});
        await expectRevert(this.vote.vote(this.nft.address, 1, 50, { from: voter}), "transfer amount exceeds balance")

        let bal = await this.erc20.balanceOf(owner);
        assert.equal(bal.toString(), 40)
        bal = await this.erc20.balanceOf(dead);
        assert.equal(bal.toString(), 40)
    })

    it("setFeeAddress", async() => {
        await expectRevert(this.vote.setFeeAddress(voter, {from: voter}), "caller is not the owner")
    })
})