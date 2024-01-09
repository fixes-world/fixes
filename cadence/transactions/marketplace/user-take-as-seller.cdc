// Thirdparty imports
import "MetadataViews"
import "FungibleToken"
import "FlowToken"
// Fixes imports
import "Fixes"
import "FixesAvatar"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20TradingRecord"
import "FRC20Storefront"
import "FRC20Marketplace"
import "FRC20MarketManager"

transaction(
    tick: String,
    rankedId: String,
    sellAmount: UFix64,
) {
    let market: &FRC20Marketplace.Market{FRC20Marketplace.MarketPublic}
    let listedItem: FRC20Marketplace.ListedItem
    let listing: &FRC20Storefront.Listing{FRC20Storefront.ListingPublic}
    let storefront: &FRC20Storefront.Storefront{FRC20Storefront.StorefrontPublic}
    let ins: &Fixes.Inscription

    prepare(acct: AuthAccount) {
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

        self.listedItem = self.market.getListedItemByRankdedId(rankedId: rankedId)
            ?? panic("Could not borrow reference to the listed item")

        /** ------------- Start -- FRC20 Storefront Initialization -------------  */
        self.storefront = self.listedItem.borrowStorefront()
            ?? panic("Could not borrow reference to the NFTStorefront")

        self.listing = self.listedItem.borrowListing()
            ?? panic("Could not borrow reference to the listing")

        let listingDetails = self.listing.getDetails()
        assert(
            listingDetails.status == FRC20Storefront.ListingStatus.Available,
            message: "The listing is not available"
        )
        assert(
            listingDetails.type == FRC20Storefront.ListingType.FixedPriceSellNow,
            message: "The listing is not a fixed price buy now listing"
        )
        assert(
            listingDetails.tick == tick,
            message: "The listing is not for the FRC20 token with tick ".concat(tick)
        )
        /** ------------- End --------------------------------------------------  */

        /** ------------- Start -- FRC20 Marketing Account General Initialization -------------  */
        // Ensure hooks are initialized
        if acct.borrow<&AnyResource>(from: FRC20FTShared.TransactionHookStoragePath) == nil {
            let hooks <- FRC20FTShared.createHooks()
            acct.save(<- hooks, to: FRC20FTShared.TransactionHookStoragePath)
            // link the hooks to the public path
            acct.unlink(FRC20FTShared.TransactionHookPublicPath)
            acct.link<&FRC20FTShared.Hooks{FRC20FTShared.TransactionHook}>(FRC20FTShared.TransactionHookPublicPath, target: FRC20FTShared.TransactionHookStoragePath)
        }
        // borrow the hooks reference
        let hooksRef = acct.borrow<&FRC20FTShared.Hooks>(from: FRC20FTShared.TransactionHookStoragePath)
            ?? panic("The hooks were not created")

        // Ensure Trading Records is initialized
        if acct.borrow<&AnyResource>(from: FRC20TradingRecord.TradingRecordsStoragePath) == nil {
            let tradingRecords <- FRC20TradingRecord.createTradingRecords(tick)
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

        /** ------------- Start -- Inscription Initialization -------------  */
        // basic attributes
        let mimeType = "text/plain"
        let metaProtocol = "frc20"
        let dataStr = "op=list-take-sellnow,tick=".concat(tick)
            .concat(",amt=").concat(sellAmount.toString())
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
        // Withdraw tokens from the signer's stored vault
        // Total amount to withdraw is the estimated required value + the buy price
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
        /** ------------- End ---------------------------------------------  */
    }

    execute {
        // execute taking
        self.listing.takeSellNow(ins: self.ins, commissionRecipient: nil)

        // cleanup
        self.storefront.tryCleanupFinishedListing(self.listedItem.id)
        self.market.tryRemoveCompletedListing(rankedId: self.listedItem.rankedId)

        log("Done")
    }
}
