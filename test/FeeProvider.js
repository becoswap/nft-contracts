const expectRevert = require("@openzeppelin/test-helpers/src/expectRevert");
const { assert } = require("chai");

const FeeProvider = artifacts.require("./FeeProvider.sol");
const TestFeeProvider = artifacts.require("./TestFeeProvider.sol");


contract("FeeProvider", ([owner, user]) => {
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
        
        await expectRevert(
            this.feeProvider.setRecipient(
                owner,
                [owner],
                [1001]
            ), "max_fee"
        )

        r = await this.feeProvider.getFees(owner, 1);
        assert.equal(r[0][0], owner)
        assert.equal(r[1][0], 100)
    })

    it("only owner", async () => {
        await expectRevert(
            this.feeProvider.setRecipient(
                user,
                [user],
                [1],
                {from: user}
            ), "Ownable: caller is not the owner"
        )
    })
})