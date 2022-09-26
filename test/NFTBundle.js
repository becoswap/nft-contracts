const { expectRevert } = require("@openzeppelin/test-helpers");
const { assert, use } = require("chai");

const ERC721NFTBundle = artifacts.require("./ERC721NFTBundle.sol");
const TestErc721 = artifacts.require("./test/TestErc721.sol");

contract("ERC721NFTBundle", ([owner, user1]) => {
  beforeEach(async () => {
    this.bundle = await ERC721NFTBundle.new();
    this.nft1 = await TestErc721.new();
    this.nft2 = await TestErc721.new();
    await this.bundle.setBaseURI("beco.io/");

    await this.nft1.mint(1);
    await this.nft1.mint(2);
    await this.nft2.mint(1);
    await this.nft2.mint(2);

    await this.nft1.mint(3, { from: user1 });

    await this.nft1.setApprovalForAll(this.bundle.address, 1);
    await this.nft2.setApprovalForAll(this.bundle.address, 1);
  });

  it("create bundle", async () => {
    await this.bundle.createBundle([
      [this.nft1.address, [1]],
      [this.nft2.address, [1]],
    ]);

    let groups = await this.bundle.getBundle(1);
    assert.equal(groups[0][0], this.nft1.address);
    assert.equal(groups[0][1][0], 1);

    let tokenURI = await this.bundle.tokenURI(1);
    assert.equal(tokenURI, "beco.io/1");

    assert.equal(groups[1][0], this.nft2.address);
    assert.equal(groups[1][1][0], 1);

    assert.equal(await this.nft1.ownerOf(1), this.bundle.address);
    assert.equal(await this.nft2.ownerOf(1), this.bundle.address);

    await this.bundle.removeBundle(1);

    assert.equal(await this.nft1.ownerOf(1), owner);
    assert.equal(await this.nft2.ownerOf(1), owner);

    groups = await this.bundle.getBundle(1);
    assert.equal(groups.length, 0);
  });

  it("addBundleItems", async () => {
    await this.bundle.createBundle([
      [this.nft1.address, [1]],
      [this.nft2.address, [1]],
    ]);
    await this.bundle.addBundleItems(1, [
      [this.nft1.address, [2]],
      [this.nft2.address, [2]],
    ]);

    await expectRevert(
      this.bundle.addBundleItems(1, [[user1, [2]]]),
      "ERC721NFTBundle: not added"
    );

    let bundle = await this.bundle.getBundle(1);
    assert.equal(bundle[0][1][1], 2);
    assert.equal(bundle[1][1][1], 2);

    await this.bundle.removeBundleItems(1, [
      [this.nft1.address, [2]],
      [this.nft2.address, [2]],
    ]);

    await expectRevert(
      this.bundle.removeBundleItems(1, [[user1, [2]]]),
      "ERC721NFTBundle: not removed"
    );

    bundle = await this.bundle.getBundle(1);
    assert.equal(bundle[0][1].length, 1);
    assert.equal(bundle[1][1].length, 1);

    await this.bundle.removeBundleItems(1, [
      [this.nft1.address, [1]],
      [this.nft2.address, [1]],
    ]);

    bundle = await this.bundle.getBundle(1);
    assert.equal(bundle.length, 0);

    assert.equal(await this.nft1.ownerOf(1), owner);
    assert.equal(await this.nft1.ownerOf(2), owner);
  });

  it("invalid", async () => {
    await this.bundle.createBundle([
      [this.nft1.address, [1]],
      [this.nft2.address, [1]],
    ]);

    await expectRevert(
      this.bundle.addBundleItems(1, [[this.nft1.address, [3]]]),
      "ERC721: transfer caller is not owner nor approved"
    );

    await expectRevert(
      this.bundle.removeBundleItems(1, [[this.nft1.address, [3]]]),
      "ERC721NFTBundle: not removed"
    );

    await expectRevert(
      this.bundle.addBundleItems(1, [[this.nft1.address, [3]]], {
        from: user1,
      }),
      "ERC721NFTBundle: caller is not owner nor approved"
    );

    await expectRevert(
      this.bundle.removeBundleItems(1, [[this.nft1.address, [3]]], {
        from: user1,
      }),
      "ERC721NFTBundle: caller is not owner nor approved"
    );

    await expectRevert(
      this.bundle.removeBundle(1, { from: user1 }),
      "ERC721NFTBundle: caller is not owner nor approved"
    );

    await expectRevert(
      this.bundle.updateMetadata(1, "dsads", { from: user1 }),
      "ERC721Operator: only operator or owner"
    );
  });

  it("update metadata", async () => {
    await this.bundle.createBundle([
      [this.nft1.address, [1]],
      [this.nft2.address, [1]],
    ]);

    await this.bundle.updateMetadata(1, "hi");
    assert.equal(await this.bundle.metadata(1), "hi");
  });

  it("fingerprint", async () => {
    await this.bundle.createBundle([
      [this.nft1.address, [1]],
      [this.nft2.address, [1]],
    ]);

    const fingerprint = await this.bundle.getFingerprint(1);
    assert.equal(await this.bundle.verifyFingerprint(1, fingerprint), true);
    assert.equal(await this.bundle.verifyFingerprint(1, "0x"), false);
  });
});
