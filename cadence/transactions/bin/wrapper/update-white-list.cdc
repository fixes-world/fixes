import "FRC20NFTWrapper"
import "FixesWrappedNFT"
import "FRC20Indexer"
import "FlowToken"

transaction(
    addr: Address,
    value: Bool,
) {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        let wrapper = acct.storage.borrow<&FRC20NFTWrapper.Wrapper>(from: FRC20NFTWrapper.FRC20NFTWrapperStoragePath)
            ?? panic("Could not borrow a reference to the NFT Wrapper")
        wrapper.updateWhitelist(addr: addr, isAuthorized: value)
    }
}
