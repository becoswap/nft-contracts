const { expectRevert } = require("@openzeppelin/test-helpers");
const { assert } = require("chai");

const ERC721NFTSingleBundle = artifacts.require("./ERC721NFTSingleBundle.sol");
const TestErc721 = artifacts.require("./test/TestErc721.sol");

contract("ERC721NFTSingleBundle", ([owner, user1]) => {
  beforeEach(async () => {
    this.nft = await TestErc721.new();
    this.bundle = await ERC721NFTSingleBundle.new(this.nft.address, "A", "A");
    await this.bundle.setBaseURI("beco.io/");

    await this.nft.mint(1);
    await this.nft.mint(2);

    await this.nft.mint(3, { from: user1 });

    await this.nft.approve(this.bundle.address, 1);
    await this.nft.approve(this.bundle.address, 2);
  });

  it("update metadata", async () => {
    await this.bundle.createBundle([1], "");

    await expectRevert(
      this.bundle.updateMetadata(1, "dsads", { from: user1 }),
      "ERC721NFTSingleBundle: caller is not owner nor approved"
    );

    await this.bundle.updateMetadata(1, "hi");
    assert.equal(await this.bundle.metadata(1), "hi");
  });

  it("create bundle", async () => {
    // create bundle
    await this.bundle.createBundle([1, 2], "");

    let bundleItems = await this.bundle.getBundleItems(1);
    assert.equal(bundleItems[0], 1);
    assert.equal(bundleItems[1], 2);

    let tokenURI = await this.bundle.tokenURI(1);
    assert.equal(tokenURI, "beco.io/1");

    let bundleItemsLength = await this.bundle.bundleItemLength(1);
    assert.equal(bundleItemsLength, 2);

    // remove bundle items
    await this.bundle.removeItems(1, [1]);
    bundleItemsLength = await this.bundle.bundleItemLength(1);
    assert.equal(bundleItemsLength, 1);

    // add items
    await this.nft.approve(this.bundle.address, 1);
    await this.bundle.addItems(1, [1]);
    bundleItems = await this.bundle.getBundleItems(1);
    assert.equal(bundleItems[1], 1);
    bundleItemsLength = await this.bundle.bundleItemLength(1);
    assert.equal(bundleItemsLength, 2);

    // remove all items
    await this.bundle.removeAllItems(1);
    bundleItemsLength = await this.bundle.bundleItemLength(1);
    assert.equal(bundleItemsLength.toString(), 0);
  });

  it("remove all", async () => {
    await this.bundle.createBundle([1, 2], "");
    await this.bundle.removeItems(1, [1, 2]);
    bundleItemsLength = await this.bundle.bundleItemLength(1);
    assert.equal(bundleItemsLength, 0);
  });

  it("invalid", async () => {
    await this.bundle.createBundle([1], "");

    await expectRevert(
      this.bundle.addItems(1, [1], { from: user1 }),
      "ERC721NFTSingleBundle: caller is not owner nor approved"
    );
    await expectRevert(
      this.bundle.removeItems(1, [1], { from: user1 }),
      "ERC721NFTSingleBundle: caller is not owner nor approved"
    );
    await expectRevert(
      this.bundle.removeAllItems(1, { from: user1 }),
      "ERC721NFTSingleBundle: caller is not owner nor approved"
    );
    await expectRevert(
      this.bundle.removeItems(1, [2]),
      "ERC721NFTSingleBundle: not removed"
    );

    await expectRevert(
      this.bundle.addItems(1, [3]),
      "ERC721: transfer caller is not owner nor approved"
    );
  });

  it("fingerprint", async () => {
    await this.bundle.createBundle([1], "");

    const fingerprint = await this.bundle.getFingerprint(1);
    assert.equal(await this.bundle.verifyFingerprint(1, fingerprint), true);
    assert.equal(await this.bundle.verifyFingerprint(1, "0x"), false);
  });
});
