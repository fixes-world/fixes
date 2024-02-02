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
    tick: String,
    buyAmount: UFix64,
    buyPrice: UFix64,
    commissionAddr: Address,
    customID: String?
) {
    let market: &FRC20Marketplace.Market{FRC20Marketplace.MarketPublic}
    let storefront: &FRC20Storefront.Storefront
    let flowTokenReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
    let ins: @Fixes.Inscription

    prepare(acct: AuthAccount) {
        /** ------------- Start -- FRC20 Marketing Account General Initialization -------------  */
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

        /** ------------- Start -- FRC20 Storefront Initialization -------------  */
        // Create Storefront if it doesn't exist
        if acct.borrow<&AnyResource>(from: FRC20Storefront.StorefrontStoragePath) == nil {
            acct.save(<- FRC20Storefront.createStorefront(), to: FRC20Storefront.StorefrontStoragePath)
            acct.unlink(FRC20Storefront.StorefrontPublicPath)
            acct.link<&FRC20Storefront.Storefront{FRC20Storefront.StorefrontPublic}>(FRC20Storefront.StorefrontPublicPath, target: FRC20Storefront.StorefrontStoragePath)
        }
        self.storefront = acct.borrow<&FRC20Storefront.Storefront>(from: FRC20Storefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")

        self.flowTokenReceiver = acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        assert(self.flowTokenReceiver.check(), message: "Missing or mis-typed FlowToken receiver")
        /** ------------- End --------------------------------------------------  */

        /** ------------- Start -- Inscription Initialization -------------  */
        // basic attributes
        let mimeType = "text/plain"
        let metaProtocol = "frc20"
        let dataStr = "op=list-sellnow,tick=".concat(tick)
            .concat(",amt=").concat(buyAmount.toString())
            .concat(",price=").concat(buyPrice.toString())
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
        let flowToReserve <- vaultRef.withdraw(amount: estimatedReqValue + buyPrice)

        // Create the Inscription first
        self.ins <- Fixes.createInscription(
            // Withdraw tokens from the signer's stored vault
            value: <- (flowToReserve as! @FlowToken.Vault),
            mimeType: mimeType,
            metadata: metadata,
            metaProtocol: metaProtocol,
            encoding: nil,
            parentId: nil
        )
        /** ------------- End ---------------------------------------------  */

        // Borrow a reference to the FRC20Marketplace contract
        self.market = FRC20MarketManager.borrowMarket(tick)
            ?? panic("Could not borrow reference to the FRC20Market")
    }

    pre {
        self.market.canAccess(addr: self.storefront.owner!.address): "You are not allowed to access this market for now."
    }

    execute {
        let commissionFlowRecipient = getAccount(commissionAddr)
            .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        assert(commissionFlowRecipient.check(), message: "Invalid commission recipient")

        // add to user's storefront
        let listingId = self.storefront.createListing(
            ins: <- self.ins,
            commissionRecipientCaps: [commissionFlowRecipient],
            customID: customID
        )

        // add to market
        self.market.addToList(
            storefront: self.storefront.owner!.address,
            listingId: listingId
        )

        log("Done: list as sell now")
    }
}

