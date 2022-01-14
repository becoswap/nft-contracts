const { assert } = require("chai");

const FeeProvider = artifacts.require("./FeeProvider.sol");


contract("FeeProvider", ([owner]) => {
    beforeEach(async () => {
        this.feeProvider = await FeeProvider.new();
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