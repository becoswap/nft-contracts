const BidArtworkNFT = artifacts.require("./artwork/BidNFT.sol");
const ArtworkNFT = artifacts.require("./artwork/ArtworkNFT.sol");
const TestErc20 = artifacts.require("./test/TestErc20.sol");

module.exports = async function(deployer) {
  await deployer.deploy(TestErc20)
  await deployer.deploy(ArtworkNFT, "Demo", "DEMO", "0x000000000000000000000000000000000000dead", 5)
  await deployer.deploy(BidArtworkNFT, ArtworkNFT.address, TestErc20.address, "0x000000000000000000000000000000000000dead", 5);
};