// Third Party Imports
import "NonFungibleToken"
import "MetadataViews"
import "FungibleToken"
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
) {
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

        /** ------------- Start -- FRC20 Semi NFT Collection Initialization ------------  */
        // ensure resource
        if acct.storage.borrow<&AnyResource>(from: FRC20SemiNFT.CollectionStoragePath) == nil {
            acct.storage.save(<- FRC20SemiNFT.createEmptyCollection(nftType: Type<@FRC20SemiNFT.NFT>()), to: FRC20SemiNFT.CollectionStoragePath)
        }

        // link to public capability
        if acct
            .capabilities.get<&FRC20SemiNFT.Collection>(FRC20SemiNFT.CollectionPublicPath)
            .borrow() == nil {
            acct.capabilities.unpublish(FRC20SemiNFT.CollectionPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20SemiNFT.Collection>(
                    FRC20SemiNFT.CollectionStoragePath
                ),
                at: FRC20SemiNFT.CollectionPublicPath
            )
        }
        /** ------------- End ---------------------------------------------------------- */

        /** ------------- Start -- FRC20 Delegator General Initialization -------------  */
        if acct.storage.borrow<&AnyResource>(from: FRC20Staking.DelegatorStoragePath) == nil {
            let cap = acct.capabilities.storage
                .issue<auth(NonFungibleToken.Withdraw, NonFungibleToken.Update) &FRC20SemiNFT.Collection>(FRC20SemiNFT.CollectionStoragePath)
            acct.storage.save(<- FRC20Staking.createDelegator(cap), to: FRC20Staking.DelegatorStoragePath)
        }

        if acct
            .capabilities.get<&FRC20Staking.Delegator>(FRC20Staking.DelegatorPublicPath)
            .borrow() == nil {
            acct.capabilities.unpublish(FRC20Staking.DelegatorPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20Staking.Delegator>(
                    FRC20Staking.DelegatorStoragePath
                ),
                at: FRC20Staking.DelegatorPublicPath
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
        let vaultRef = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
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
        FRC20StakingManager.donateToStakingPool(tick: stakeTick, ins: self.ins)
        log("Donate to staking pool successfully!")
    }
}
