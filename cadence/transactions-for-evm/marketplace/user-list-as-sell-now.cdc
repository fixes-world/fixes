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
import "EVMAgent"

transaction(
    tick: String,
    buyAmount: UFix64,
    buyPrice: UFix64,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    let market: &{FRC20Marketplace.MarketPublic}
    let storefront: auth(FRC20Storefront.Owner) &FRC20Storefront.Storefront
    let flowTokenReceiver: Capability<&{FungibleToken.Receiver}>
    let ins: @Fixes.Inscription
    let marginVault: @FlowToken.Vault

    prepare(signer: auth(Storage, Capabilities) &Account) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "user-list-as-sell-now(String|UFix64|UFix64)",
            params: [tick, buyAmount.toString(), buyPrice.toString()],
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp
        )
        /** ------------- EVMAgency: End --------------------------------------- */

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

        self.flowTokenReceiver = acct.capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        assert(self.flowTokenReceiver.check(), message: "Missing or mis-typed FlowToken receiver")
        /** ------------- End --------------------------------------------------  */

        /** ------------- Start -- Inscription Initialization -------------  */
        // Create the Inscription metadata
        let dataStr = FixesInscriptionFactory.buildMarketListSellNow(tick: tick, amount: buyAmount, price: buyPrice)

        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)

        // Get a reference to the signer's stored vault
        let vaultRef = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")
        // Withdraw tokens from the signer's stored vault
        // Total amount to withdraw is the estimated required value + the buy price
        let flowToReserve <- vaultRef.withdraw(amount: estimatedReqValue)

        // Create the Inscription first
        self.ins <- FixesInscriptionFactory.createFrc20Inscription(dataStr, <- (flowToReserve as! @FlowToken.Vault))

        // Deposit the payment flow vault to the inscription vault
        self.marginVault <- vaultRef.withdraw(amount: buyPrice) as! @FlowToken.Vault

        /** ------------- End ---------------------------------------------  */

        // Borrow a reference to the FRC20Marketplace contract
        self.market = FRC20MarketManager.borrowMarket(tick)
            ?? panic("Could not borrow reference to the FRC20Market")
    }

    pre {
        self.market.canAccess(addr: self.storefront.owner!.address): "You are not allowed to access this market for now."
    }

    execute {
        // add to user's storefront
        let listingId = self.storefront.createListing(
            ins: <- self.ins,
            marginVault: <- self.marginVault,
            commissionRecipientCaps: nil,
            customID: nil
        )

        // add to market
        self.market.addToList(
            storefront: self.storefront.owner!.address,
            listingId: listingId
        )

        log("Done: list as sell now")
    }
}

