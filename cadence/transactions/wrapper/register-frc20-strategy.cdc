import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"
import "FRC20Indexer"
import "FlowToken"

transaction(
    nftTypeIdentifer: String,
    tick: String,
    alloc: UFix64,
    copies: UInt64,
    transferAmt: UFix64?,
) {
    let wrapper: &FRC20NFTWrapper.Wrapper{FRC20NFTWrapper.WrapperPublic}
    let ins: &Fixes.Inscription

    prepare(acct: AuthAccount) {
        let indexerAddr = FRC20Indexer.getAddress()
        self.wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: indexerAddr)

        // basic attributes
        let mimeType = "text/plain"
        let metaProtocol = "frc20"
        let dataStr = transferAmt != nil
            ? "op=transfer,tick=".concat(tick).concat(",amt=").concat(transferAmt!.toString()).concat(",to=").concat(indexerAddr.toString())
            : "tick=".concat(tick)
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
            ins: self.ins
        )
    }
}
