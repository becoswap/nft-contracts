const { assert } = require("chai");

const FeeProvider = artifacts.require("./FeeProvider.sol");
const TestFeeProvider = artifacts.require("./TestFeeProvider.sol");


contract("FeeProvider", ([owner]) => {
    beforeEach(async () => {
        this.feeProvider = await FeeProvider.new();
        this.testFeeProvider = await TestFeeProvider.new();
    })

    it ("setProvider", async () => {
        await this.feeProvider.setProvider(owner, this.testFeeProvider.address);
        await this.testFeeProvider.setRecipient([owner], [100]);

        const r = await this.feeProvider.getFees(owner, 1);
        assert.equal(r[0][0], owner)
        assert.equal(r[1][0], 100)
    })

    it ("setRecipient", async () => {
        let r = await this.feeProvider.getFees(owner, 1);
        assert.equal(r[0].length, 0)
        assert.equal(r[1].length, 0)

        await this.feeProvider.setRecipient(
            owner,
            [owner],
            [100]
        )

        r = await this.feeProvider.getFees(owner, 1);
        assert.equal(r[0][0], owner)
        assert.equal(r[1][0], 100)
    })
})