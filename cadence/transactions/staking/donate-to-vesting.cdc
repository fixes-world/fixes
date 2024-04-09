// Third Party Imports
import "NonFungibleToken"
import "MetadataViews"
import "FlowToken"
// Fixes imports
import "Fixes"
import "FixesInscriptionFactory"
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
    vestingBatchAmount: UInt32,
    vestingInterval: UFix64,
) {
    let ins: &Fixes.Inscription

    prepare(acct: AuthAccount) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

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
        // create the metadata
        let dataStr = FixesInscriptionFactory.buildStakeDonate(
            tick: rewardTick != "" ? rewardTick : nil,
            amount: amount
        )

        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)

        // Get a reference to the signer's stored vault
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")
        // Withdraw tokens from the signer's stored vault
        let flowToReserve <- vaultRef.withdraw(amount: estimatedReqValue)

        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            dataStr,
            <- (flowToReserve as! @FlowToken.Vault),
            store
        )
        // borrow a reference to the new Inscription
        self.ins = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow reference to the new Inscription!")

        // Deposit the payment flow vault to the inscription vault
        if rewardTick == "" {
            let donateVault <- vaultRef.withdraw(amount: amount)
            self.ins.deposit(<- (donateVault as! @FlowToken.Vault))
        }
        /** ------------- End ---------------------------------------------  */
    }

    execute {
        FRC20StakingManager.donateToVesting(
            tick: stakeTick,
            ins: self.ins,
            vestingBatchAmount: vestingBatchAmount,
            vestingInterval: vestingInterval
        )
        log("Donation done!")
    }
}
