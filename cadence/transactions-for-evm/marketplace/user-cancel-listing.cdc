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
import "EVMAgent"

transaction(
    listingId: UInt64,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    let storefront: auth(FRC20Storefront.Owner) &FRC20Storefront.Storefront
    let listing: &{FRC20Storefront.ListingPublic}

    prepare(signer: auth(Storage, Capabilities) &Account) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "user-cancel-listing(UInt64)",
            params: [listingId.toString()],
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp
        )
        /** ------------- EVMAgency: End --------------------------------------- */

        /** ------------- Start -- FRC20 Storefront Initialization -------------  */
        // Create Storefront if it doesn't exist
        if acct.storage.borrow<&AnyResource>(from: FRC20Storefront.StorefrontStoragePath) == nil {
            acct.storage.save(<- FRC20Storefront.createStorefront(), to: FRC20Storefront.StorefrontStoragePath)
            acct.capabilities.unpublish(FRC20Storefront.StorefrontPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20Storefront.Storefront>(FRC20Storefront.StorefrontStoragePath),
                at: FRC20Storefront.StorefrontPublicPath
            )
        }
        self.storefront = acct.storage
            .borrow<auth(FRC20Storefront.Owner) &FRC20Storefront.Storefront>(from: FRC20Storefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")
        /** ------------- End --------------------------------------------------  */

        self.listing = self.storefront.borrowListing(listingId)
            ?? panic("Failed to borrow listing:".concat(listingId.toString()))

        let tick = self.listing.getTickName()

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

