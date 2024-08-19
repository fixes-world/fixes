import "FRC20NFTWrapper"
import "FixesWrappedNFT"
import "FRC20Indexer"
import "FungibleToken"
import "FlowToken"

transaction() {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        if acct.storage.borrow<&AnyResource>(from: FRC20NFTWrapper.FRC20NFTWrapperStoragePath) == nil {
            acct.storage.save(<- FRC20NFTWrapper.createNewWrapper(), to: FRC20NFTWrapper.FRC20NFTWrapperStoragePath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20NFTWrapper.Wrapper>(FRC20NFTWrapper.FRC20NFTWrapperStoragePath),
                at: FRC20NFTWrapper.FRC20NFTWrapperPublicPath
            )
        }

        // Get a reference to the signer's stored vault
        let vaultRef = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")
        let toDonate <- vaultRef.withdraw(amount: 1.0)

        FRC20NFTWrapper.donate(addr: acct.address, <- (toDonate as! @FlowToken.Vault))

        let wrapperIndexer = FRC20NFTWrapper.borrowWrapperIndexerPublic()
        if !wrapperIndexer.hasRegisteredWrapper(addr: acct.address) {
            let ref = acct.storage.borrow<&FRC20NFTWrapper.Wrapper>(from: FRC20NFTWrapper.FRC20NFTWrapperStoragePath)
                ?? panic("Could not borrow reference to the owner's Wrapper!")
            wrapperIndexer.registerWrapper(wrapper: ref)
        }
    }
}
