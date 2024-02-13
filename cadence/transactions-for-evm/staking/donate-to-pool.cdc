// Third Party Imports
import "NonFungibleToken"
import "MetadataViews"
import "FlowToken"
// Fixes imports
import "Fixes"
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20SemiNFT"
import "FRC20Staking"
import "FRC20StakingManager"

transaction(
    stakeTick: String,
    rewardTick: String,
    amount: UFix64,
) {
    let ins: &Fixes.Inscription

    prepare(acct: AuthAccount) {

        /** ------------- Start -- FRC20 Semi NFT Collection Initialization ------------  */
        // ensure resource
        if acct.borrow<&AnyResource>(from: FRC20SemiNFT.CollectionStoragePath) == nil {
            acct.save(<- FRC20SemiNFT.createEmptyCollection(), to: FRC20SemiNFT.CollectionStoragePath)
        }

        // link to public capability
        if acct
            .getCapability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(FRC20SemiNFT.CollectionPublicPath)
            .borrow() == nil {
            acct.unlink(FRC20SemiNFT.CollectionPublicPath)
            acct.link<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(
                FRC20SemiNFT.CollectionPublicPath,
                target: FRC20SemiNFT.CollectionStoragePath
            )
            // Link private path (will be deprecated in Cadence 1.0)
            acct.unlink(FRC20SemiNFT.CollectionPrivatePath)
            acct.link<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
                FRC20SemiNFT.CollectionPrivatePath,
                target: FRC20SemiNFT.CollectionStoragePath
            )
        }
        /** ------------- End ---------------------------------------------------------- */

        /** ------------- Start -- FRC20 Delegator General Initialization -------------  */
        if acct.borrow<&AnyResource>(from: FRC20Staking.DelegatorStoragePath) == nil {
            let semiNFTCol = acct
                .getCapability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(FRC20SemiNFT.CollectionPrivatePath)
            acct.save(<- FRC20Staking.createDelegator(semiNFTCol), to: FRC20Staking.DelegatorStoragePath)
        }

        if acct
            .getCapability<&FRC20Staking.Delegator{FRC20Staking.DelegatorPublic}>(FRC20Staking.DelegatorPublicPath)
            .borrow() == nil {
            acct.unlink(FRC20Staking.DelegatorPublicPath)
            acct.link<&FRC20Staking.Delegator{FRC20Staking.DelegatorPublic}>(
                FRC20Staking.DelegatorPublicPath,
                target: FRC20Staking.DelegatorStoragePath
            )
        }
        /** ------------- End ---------------------------------------------------------- */

        /** ------------- Start -- Inscription Initialization -------------  */
        // basic attributes
        let mimeType = "text/plain"
        let metaProtocol = "frc20"
        var dataStr = "op=withdraw,usage=donate"
        if rewardTick != "" {
            dataStr = dataStr
                .concat(",tick=").concat(rewardTick)
                .concat(",amt=").concat(amount.toString())
        }
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
        var withdrawAmount = rewardTick == "" ? estimatedReqValue + amount : estimatedReqValue
        // Withdraw tokens from the signer's stored vault
        let flowToReserve <- vaultRef.withdraw(amount: withdrawAmount)

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
        /** ------------- End ---------------------------------------------  */
    }

    execute {
        FRC20StakingManager.donateToStakingPool(tick: stakeTick, ins: self.ins)
        log("Donate to staking pool successfully!")
    }
}
