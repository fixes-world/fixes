import "FRC20NFTWrapper"
import "FixesWrappedNFT"
import "FRC20Indexer"
import "FlowToken"

transaction() {
    prepare(acct: AuthAccount) {
        if acct.borrow<&AnyResource>(from: FRC20NFTWrapper.FRC20NFTWrapperStoragePath) == nil {
            acct.save(<- FRC20NFTWrapper.createNewWrapper(), to: FRC20NFTWrapper.FRC20NFTWrapperStoragePath)
            acct.link<&FRC20NFTWrapper.Wrapper{FRC20NFTWrapper.WrapperPublic}>(
                FRC20NFTWrapper.FRC20NFTWrapperPublicPath,
                target: FRC20NFTWrapper.FRC20NFTWrapperStoragePath
            )
        }

        // Get a reference to the signer's stored vault
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")
        let toDonate <- vaultRef.withdraw(amount: 1.0)

        FRC20NFTWrapper.donate(addr: acct.address, <- (toDonate as! @FlowToken.Vault))
    }
}
