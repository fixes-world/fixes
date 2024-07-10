// Thirdparty imports
import "MetadataViews"
import "FungibleToken"
import "FlowToken"
// Fixes imports
import "Fixes"
import "FixesAvatar"
import "FixesHeartbeat"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20TradingRecord"
import "FRC20Storefront"
import "FRC20Marketplace"
import "FRC20MarketManager"

transaction(
    listingId: UInt64
) {
    let storefront: &FRC20Storefront.Storefront
    let listing: &FRC20Storefront.Listing{FRC20Storefront.ListingPublic}

    prepare(acct: AuthAccount) {
        /** ------------- Start -- FRC20 Storefront Initialization -------------  */
        // Create Storefront if it doesn't exist
        if acct.borrow<&AnyResource>(from: FRC20Storefront.StorefrontStoragePath) == nil {
            acct.save(<- FRC20Storefront.createStorefront(), to: FRC20Storefront.StorefrontStoragePath)
            acct.unlink(FRC20Storefront.StorefrontPublicPath)
            acct.link<&FRC20Storefront.Storefront{FRC20Storefront.StorefrontPublic}>(FRC20Storefront.StorefrontPublicPath, target: FRC20Storefront.StorefrontStoragePath)
        }
        self.storefront = acct.borrow<&FRC20Storefront.Storefront>(from: FRC20Storefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")
        /** ------------- End --------------------------------------------------  */

        self.listing = self.storefront.borrowListing(listingId)
            ?? panic("Failed to borrow listing:".concat(listingId.toString()))

        let tick = self.listing.getTickName()

        /** ------------- Start -- TradingRecords General Initialization -------------  */
        // Ensure hooks are initialized
        if acct.borrow<&AnyResource>(from: FRC20FTShared.TransactionHookStoragePath) == nil {
            let hooks <- FRC20FTShared.createHooks()
            acct.save(<- hooks, to: FRC20FTShared.TransactionHookStoragePath)
        }

        // link the hooks to the public path
        if acct
            .getCapability<&FRC20FTShared.Hooks{FRC20FTShared.TransactionHook, FixesHeartbeat.IHeartbeatHook}>(FRC20FTShared.TransactionHookPublicPath)
            .borrow() == nil {
            // link the hooks to the public path
            acct.unlink(FRC20FTShared.TransactionHookPublicPath)
            acct.link<&FRC20FTShared.Hooks{FRC20FTShared.TransactionHook, FixesHeartbeat.IHeartbeatHook}>(
                FRC20FTShared.TransactionHookPublicPath,
                target: FRC20FTShared.TransactionHookStoragePath
            )
        }

        // borrow the hooks reference
        let hooksRef = acct.borrow<&FRC20FTShared.Hooks>(from: FRC20FTShared.TransactionHookStoragePath)
            ?? panic("The hooks were not created")

        // Ensure Trading Records is initialized
        if acct.borrow<&AnyResource>(from: FRC20TradingRecord.TradingRecordsStoragePath) == nil {
            let tradingRecords <- FRC20TradingRecord.createTradingRecords(nil)
            acct.save(<- tradingRecords, to: FRC20TradingRecord.TradingRecordsStoragePath)
            // link the trading records to the public path
            acct.unlink(FRC20TradingRecord.TradingRecordsPublicPath)
            acct.link<&FRC20TradingRecord.TradingRecords{FRC20TradingRecord.TradingRecordsPublic, FRC20TradingRecord.TradingStatusViewer, FRC20FTShared.TransactionHook}>(FRC20TradingRecord.TradingRecordsPublicPath, target: FRC20TradingRecord.TradingRecordsStoragePath)
        }

        // Ensure trading record hook is added to the hooks
        // get the public capability of the trading record hook
        let tradingRecordsCap = acct
            .getCapability<&FRC20TradingRecord.TradingRecords{FRC20TradingRecord.TradingRecordsPublic, FRC20TradingRecord.TradingStatusViewer, FRC20FTShared.TransactionHook}>(
                FRC20TradingRecord.TradingRecordsPublicPath
            )
        assert(tradingRecordsCap.check(), message: "The trading record hook is not valid")
        // get the reference of the trading record hook
        let recordsRef = tradingRecordsCap.borrow() ?? panic("The trading record hook is not valid")
        if !hooksRef.hasHook(recordsRef.getType()) {
            hooksRef.addHook(tradingRecordsCap)
        }

        // Ensure Fixes Avatar is initialized
        if acct.borrow<&AnyResource>(from: FixesAvatar.AvatarStoragePath) == nil {
            acct.save(<- FixesAvatar.create(), to: FixesAvatar.AvatarStoragePath)
            // link the avatar to the public path
            acct.unlink(FixesAvatar.AvatarPublicPath)
            acct.link<&FixesAvatar.Profile{FixesAvatar.ProfilePublic, FRC20FTShared.TransactionHook, MetadataViews.Resolver}>(FixesAvatar.AvatarPublicPath, target: FixesAvatar.AvatarStoragePath)
        }
        let profileCap = FixesAvatar.getProfileCap(acct.address)
        assert(profileCap.check(), message: "The profile is not valid")
        let profileRef = profileCap.borrow() ?? panic("The profile is not valid")
        if !hooksRef.hasHook(profileRef.getType()) {
            hooksRef.addHook(profileCap)
        }
        /** ------------- End -----------------------------------------------------------------  */
    }

    execute {
        let userAddress = self.storefront.owner!.address
        let details = self.listing.getDetails()

        let market = FRC20MarketManager.borrowMarket(details.tick)
        var rankedIdInMarket: String? = nil
        // get from market
        if market != nil  {
            let accessible = market!.canAccess(addr: userAddress)
            if accessible {
                if let item = market!.getListedItem(type: details.type, rank: details.priceRank(), id: listingId) {
                    rankedIdInMarket = item.rankedId
                }
            }
        }

        // remove listing
        let ins <- self.storefront.removeListing(listingResourceID: listingId)
        destroy ins
        // remove from market

        if rankedIdInMarket != nil {
            market!.tryRemoveCompletedListing(rankedId: rankedIdInMarket!)
        }
        log("Done: User cancel list")
    }
}

