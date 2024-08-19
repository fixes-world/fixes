import "Fixes"
import "FixesInscriptionFactory"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"
import "FRC20Indexer"
import "FungibleToken"
import "FlowToken"

transaction(
    wrapperAddress: Address,
    nftTypeIdentifer: String,
    tick: String,
    alloc: UFix64,
    copies: UInt64,
    cond: String?,
) {
    let wrapper: &{FRC20NFTWrapper.WrapperPublic}
    let ins: auth(Fixes.Extractable) &Fixes.Inscription

    prepare(acct: auth(Storage, Capabilities) &Account) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.storage.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        // if the wrapper address is the same as the signer's address, then we need to create a new wrapper
        if wrapperAddress == acct.address {
            // ensure that the wrapper exists
            if acct.storage.borrow<&AnyResource>(from: FRC20NFTWrapper.FRC20NFTWrapperStoragePath) == nil {
                acct.storage.save(<- FRC20NFTWrapper.createNewWrapper(), to: FRC20NFTWrapper.FRC20NFTWrapperStoragePath)
                acct.capabilities.publish(
                    acct.capabilities.storage.issue<&FRC20NFTWrapper.Wrapper>(FRC20NFTWrapper.FRC20NFTWrapperStoragePath),
                    at: FRC20NFTWrapper.FRC20NFTWrapperPublicPath
                )

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

        self.wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: wrapperAddress) ?? panic("Could not borrow public reference")
        assert(
            self.wrapper.isAuthorizedToRegister(addr: acct.address),
            message: "Signer is not authorized to register!"
        )

        let transferAmt = alloc * UFix64(copies)
        let dataStr = FixesInscriptionFactory.buildTransferFRC20(
            tick: tick,
            to: FRC20Indexer.getAddress(),
            amt: transferAmt
        )
        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)

        // Get a reference to the signer's stored vault
        let vaultRef = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")
        let flowToReserve <- vaultRef.withdraw(amount: estimatedReqValue)

        // Create the Inscription first
        let newInsId= FixesInscriptionFactory.createAndStoreFrc20Inscription(
            dataStr,
            <- (flowToReserve as! @FlowToken.Vault),
            store
        )
        // borrow a reference to the new Inscription
        self.ins = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow reference to the new Inscription!")
    }

    execute {
        self.wrapper.registerFRC20Strategy(
            type: FRC20NFTWrapper.asCollectionType(nftTypeIdentifer),
            alloc: alloc,
            copies: copies,
            cond: cond,
            ins: self.ins
        )
    }
}
