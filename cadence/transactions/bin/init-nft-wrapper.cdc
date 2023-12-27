import "FRC20NFTWrapper"
import "FixesWrappedNFT"
import "FRC20Indexer"
import "FlowToken"

transaction() {
    prepare(acct: AuthAccount) {
        let privCap = acct
            .getCapability<&FixesWrappedNFT.NFTMinter{FixesWrappedNFT.Minter}>(FixesWrappedNFT.MinterPrivatePath)
        assert(privCap.borrow() != nil, message: "Missing or mis-typed NFTMinter private capability")

        if acct.borrow<&AnyResource>(from: FRC20NFTWrapper.FRC20NFTWrapperStoragePath) == nil {
            acct.save(<- FRC20NFTWrapper.createNewWrapper(privCap), to: FRC20NFTWrapper.FRC20NFTWrapperStoragePath)
            acct.link<&FRC20NFTWrapper.Wrapper{FRC20NFTWrapper.WrapperPublic}>(
                FRC20NFTWrapper.FRC20NFTWrapperPublicPath,
                target: FRC20NFTWrapper.FRC20NFTWrapperStoragePath
            )
        }

        // Get a reference to the signer's stored vault
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
			?? panic("Could not borrow reference to the owner's Vault!")
        let toDonate <- vaultRef.withdraw(amount: 1.0)

        let addr = FRC20Indexer.getAddress()
        FRC20NFTWrapper.donate(addr: addr, <- (toDonate as! @FlowToken.Vault))
    }
}
