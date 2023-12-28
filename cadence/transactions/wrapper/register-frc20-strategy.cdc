import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"
import "FRC20Indexer"
import "FlowToken"

transaction(
    wrapperAddress: Address,
    nftTypeIdentifer: String,
    tick: String,
    alloc: UFix64,
    copies: UInt64,
    cond: String?,
    transferAmt: UFix64,
) {
    let wrapper: &FRC20NFTWrapper.Wrapper{FRC20NFTWrapper.WrapperPublic}
    let ins: &Fixes.Inscription

    prepare(acct: AuthAccount) {
        // if the wrapper address is the same as the signer's address, then we need to create a new wrapper
        if wrapperAddress == acct.address {
            // ensure that the wrapper exists
            if acct.borrow<&AnyResource>(from: FRC20NFTWrapper.FRC20NFTWrapperStoragePath) == nil {
                acct.save(<- FRC20NFTWrapper.createNewWrapper(), to: FRC20NFTWrapper.FRC20NFTWrapperStoragePath)
                acct.link<&FRC20NFTWrapper.Wrapper{FRC20NFTWrapper.WrapperPublic}>(
                    FRC20NFTWrapper.FRC20NFTWrapperPublicPath,
                    target: FRC20NFTWrapper.FRC20NFTWrapperStoragePath
                )

                // Get a reference to the signer's stored vault
                let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
                    ?? panic("Could not borrow reference to the owner's Vault!")
                let toDonate <- vaultRef.withdraw(amount: 1.0)

                FRC20NFTWrapper.donate(addr: acct.address, <- (toDonate as! @FlowToken.Vault))
            }
        }

        self.wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: wrapperAddress)
        assert(
            self.wrapper.isAuthorizedToRegister(addr: acct.address),
            message: "Signer is not authorized to register!"
        )

        // basic attributes
        let mimeType = "text/plain"
        let metaProtocol = "frc20"
        let dataStr = "op=transfer,tick=".concat(tick).concat(",amt=").concat(transferAmt.toString()).concat(",to=").concat(FRC20Indexer.getAddress().toString())
        let metadata = dataStr.utf8

        // estimate the required storage
        let estimatedReqValue = Fixes.estimateValue(
            index: Fixes.totalInscriptions,
            mimeType: mimeType,
            data: metadata,
            protocol: metaProtocol,
            encoding: nil
        )

        // Get a reference to the signer's stored vault
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")
        let flowToReserve <- vaultRef.withdraw(amount: estimatedReqValue)

        // Create the Inscription first
        let newIns <- Fixes.createInscription(
            // Withdraw tokens from the signer's stored vault
            value: <- (flowToReserve as! @FlowToken.Vault),
            mimeType: mimeType,
            metadata: metadata,
            metaProtocol: metaProtocol,
            encoding: nil,
            parentId: nil
        )
        // save the new Inscription to storage
        let newInsId = newIns.getId()
        let newInsPath = Fixes.getFixesStoragePath(index: newInsId)
        assert(
            acct.borrow<&AnyResource>(from: newInsPath) == nil,
            message: "Inscription with ID ".concat(newInsId.toString()).concat(" already exists!")
        )
        acct.save(<- newIns, to: newInsPath)

        // borrow a reference to the new Inscription
        self.ins = acct.borrow<&Fixes.Inscription>(from: newInsPath)
            ?? panic("Could not borrow reference to the new Inscription!")
    }

    execute {
        self.wrapper.registerFRC20Strategy(
            nftType: CompositeType(nftTypeIdentifer)!,
            alloc: alloc,
            copies: copies,
            cond: cond,
            ins: self.ins
        )
    }
}
