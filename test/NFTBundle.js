const { expectRevert } = require("@openzeppelin/test-helpers");
const { assert } = require("chai");

const ERC721NFTBundle = artifacts.require("./ERC721NFTBundle.sol");
const TestErc721 = artifacts.require("./test/TestErc721.sol");


contract("ERC721NFTBundle", ([owner, user1]) => {
    beforeEach(async () => {
        this.bundle = await ERC721NFTBundle.new();
        this.nft1 = await TestErc721.new();
        this.nft2 = await TestErc721.new();


        await this.nft1.mint(1);
        await this.nft2.mint(1);

        await this.nft1.approve(this.bundle.address, 1);
        await this.nft2.approve(this.bundle.address, 1);
    })


    it("create bundle", async () => {
        await this.bundle.createBundle([
            [
                this.nft1.address,
                [1]
            ],
            [
                this.nft2.address,
                [1]
            ]
        ]);


        let groups = await this.bundle.getBundle(1);
        assert.equal(groups[0][0], this.nft1.address);
        assert.equal(groups[0][1][0], 1);

        assert.equal(groups[1][0], this.nft2.address);
        assert.equal(groups[1][1][0], 1);


        assert.equal(await this.nft1.ownerOf(1), this.bundle.address);
        assert.equal(await this.nft2.ownerOf(1), this.bundle.address);

        await expectRevert(this.bundle.removeBundle(1, {from: user1}), "ERC721Burnable: caller is not owner nor approved")

        await this.bundle.removeBundle(1);

        assert.equal(await this.nft1.ownerOf(1), owner);
        assert.equal(await this.nft2.ownerOf(1), owner);

        groups = await this.bundle.getBundle(1);
        assert.equal(groups.length, 0);
    })

    
})