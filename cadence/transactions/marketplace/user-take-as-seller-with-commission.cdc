// Thirdparty imports
import "MetadataViews"
import "FungibleToken"
import "FlowToken"
// Fixes imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesAvatar"
import "FixesHeartbeat"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20TradingRecord"
import "FRC20Storefront"
import "FRC20Marketplace"
import "FRC20MarketManager"

transaction(
    tick: String,
    // RankedId => SellAmount
    batchSellItems: {String: UFix64},
) {
    let market: &{FRC20Marketplace.MarketPublic}

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

        /** ------------- Start -- FRC20 Marketplace -------------  */
        // Borrow a reference to the FRC20Marketplace contract
        self.market = FRC20MarketManager.borrowMarket(tick)
            ?? panic("Could not borrow reference to the FRC20Market")

        assert(
            self.market.getTickerName() == tick,
            message: "The market is not for the FRC20 token with tick ".concat(tick)
        )
        assert(
            self.market.canAccess(addr: acct.address),
            message: "You are not allowed to access this market for now."
        )
        /** ------------- End -------------------------------------  */

        /** ------------- Start -- TradingRecords General Initialization -------------  */
        // Ensure hooks are initialized
        if acct.storage.borrow<&AnyResource>(from: FRC20FTShared.TransactionHookStoragePath) == nil {
            let hooks <- FRC20FTShared.createHooks()
            acct.storage.save(<- hooks, to: FRC20FTShared.TransactionHookStoragePath)
        }

        // link the hooks to the public path
        if acct
            .capabilities.get<&FRC20FTShared.Hooks>(FRC20FTShared.TransactionHookPublicPath)
            .borrow() == nil {
            // link the hooks to the public path
            acct.capabilities.unpublish(FRC20FTShared.TransactionHookPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20FTShared.Hooks>(FRC20FTShared.TransactionHookStoragePath),
                at: FRC20FTShared.TransactionHookPublicPath
            )
        }

        // borrow the hooks reference
        let hooksRef = acct.storage
            .borrow<auth(FRC20FTShared.Manage) &FRC20FTShared.Hooks>(from: FRC20FTShared.TransactionHookStoragePath)
            ?? panic("The hooks were not created")

        // Ensure Trading Records is initialized
        if acct.storage.borrow<&AnyResource>(from: FRC20TradingRecord.TradingRecordsStoragePath) == nil {
            let tradingRecords <- FRC20TradingRecord.createTradingRecords(nil)
            acct.storage.save(<- tradingRecords, to: FRC20TradingRecord.TradingRecordsStoragePath)
            // link the trading records to the public path
            acct.capabilities.unpublish(FRC20TradingRecord.TradingRecordsPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20TradingRecord.TradingRecords>(FRC20TradingRecord.TradingRecordsStoragePath),
                at: FRC20TradingRecord.TradingRecordsPublicPath
            )
        }

        // Ensure trading record hook is added to the hooks
        // get the public capability of the trading record hook
        let tradingRecordsCap = acct
            .capabilities.get<&FRC20TradingRecord.TradingRecords>(
                FRC20TradingRecord.TradingRecordsPublicPath
            )
        assert(tradingRecordsCap.check(), message: "The trading record hook is not valid")
        // get the reference of the trading record hook
        let recordsRef = tradingRecordsCap.borrow() ?? panic("The trading record hook is not valid")
        if !hooksRef.hasHook(recordsRef.getType()) {
            hooksRef.addHook(tradingRecordsCap)
        }

        // Ensure Fixes Avatar is initialized
        if acct.storage.borrow<&AnyResource>(from: FixesAvatar.AvatarStoragePath) == nil {
            acct.storage.save(<- FixesAvatar.createProfile(), to: FixesAvatar.AvatarStoragePath)
            // link the avatar to the public path
            acct.capabilities.unpublish(FixesAvatar.AvatarPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FixesAvatar.Profile>(FixesAvatar.AvatarStoragePath),
                at: FixesAvatar.AvatarPublicPath
            )
        }
        let profileCap = FixesAvatar.getProfileCap(acct.address)
        assert(profileCap.check(), message: "The profile is not valid")
        let profileRef = profileCap.borrow() ?? panic("The profile is not valid")
        if !hooksRef.hasHook(profileRef.getType()) {
            hooksRef.addHook(profileCap)
        }
        /** ------------- End -----------------------------------------------------------------  */

        // Get a reference to the signer's stored vault
        let vaultRef = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        // For each buy item, check the listing
        for rankedId in batchSellItems.keys {
            let listedItem = self.market.getListedItemByRankdedId(rankedId: rankedId)
            /** ------------- Start -- FRC20 Storefront Initialization -------------  */
            // Do not panic for better UX
            if listedItem == nil {
                continue
            }
            let storefront = listedItem!.borrowStorefront()
            let listing = listedItem!.borrowListing()
            // Do not panic for better UX
            if storefront == nil || listing == nil {
                continue
            }
            let listingDetails = listing!.getDetails()
            // Do not panic for better UX
            if listingDetails.status != FRC20Storefront.ListingStatus.Available {
                continue
            }
            if listingDetails.type != FRC20Storefront.ListingType.FixedPriceSellNow {
                continue
            }
            if listingDetails.tick != tick {
                continue
            }
            /** ------------- End --------------------------------------------------  */

            var commissionFlowRecipient: Capability<&FlowToken.Vault>? = nil
            if let receivers = listing!.getAllowedCommissionReceivers() {
                if receivers.length > 0 {
                    commissionFlowRecipient = receivers[0]
                    assert(commissionFlowRecipient!.check(), message: "Invalid commission recipient")
                }
            }

            let sellAmount = batchSellItems[rankedId]!

            /** ------------- Start -- Inscription Initialization -------------  */
            // create the metadata
            let dataStr = FixesInscriptionFactory.buildMarketTakeSellNow(tick: tick, amount: sellAmount)

            // estimate the required storage
            let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)

            // Withdraw tokens from the signer's stored vault
            // Total amount to withdraw is the estimated required value + the buy price
            let flowToReserve <- vaultRef.withdraw(amount: estimatedReqValue)

            // Create the Inscription first
            let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
                dataStr,
                <- (flowToReserve as! @FlowToken.Vault),
                store
            )
            // borrow a reference to the new Inscription
            let insRef = store.borrowInscriptionWritableRef(newInsId)
                ?? panic("Could not borrow reference to the new Inscription!")
            /** ------------- End ---------------------------------------------  */

            // execute taking
            listing?.takeSellNow(ins: insRef, commissionRecipient: commissionFlowRecipient)

            // cleanup
            self.market.tryRemoveCompletedListing(rankedId: listedItem!.rankedId)
        }
    }

    execute {
        log("Done: user take as seller with commission")
    }
}

