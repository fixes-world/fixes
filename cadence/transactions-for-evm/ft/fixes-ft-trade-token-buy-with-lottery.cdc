import "FlowToken"
import "FungibleToken"
import "MetadataViews"
import "ViewResolver"
import "ScopedFTProviders"
import "FlowEVMBridgeConfig"
// Fixes Imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FRC20FTShared"
import "FixesHeartbeat"
import "FRC20TradingRecord"
import "FixesAvatar"
import "FixesTradablePool"
import "FGameLottery"
import "FGameLotteryFactory"
import "EVMAgent"

transaction(
    coinAddress: Address,
    cost: UFix64,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    let pool: &FixesTradablePool.TradableLiquidityPool
    let scopedProvider: @ScopedFTProviders.ScopedFTProvider
    let recipient: &{FungibleToken.Receiver}
    let ticketRecipient: Capability<&FGameLottery.TicketCollection>
    let inscriptionStore: auth(Fixes.Manage) &Fixes.InscriptionsStore

    prepare(signer: auth(Storage, Capabilities) &Account) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "fixes-ft-trade-token-buy-with-lottery(Address|UFix64)",
            params: [coinAddress.toString(), cost.toString()],
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp
        )
        /** ------------- EVMAgency: End --------------------------------------- */

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

        self.inscriptionStore = store

        /** ------------- Initialize TicketCollection - Start ---------------- */
        // If the user doesn't have a TicketCollection yet, create one
        if acct.storage.borrow<&FGameLottery.TicketCollection>(from: FGameLottery.userCollectionStoragePath) == nil {
            acct.storage.save(<- FGameLottery.createTicketCollection(), to: FGameLottery.userCollectionStoragePath)
        }
        // Link public capability to the account
        if acct
            .capabilities.get<&FGameLottery.TicketCollection>(FGameLottery.userCollectionPublicPath)
            .borrow() == nil {
            acct.capabilities.unpublish(FGameLottery.userCollectionPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FGameLottery.TicketCollection>(FGameLottery.userCollectionStoragePath),
                at: FGameLottery.userCollectionPublicPath
            )
        }
        self.ticketRecipient = FGameLottery.getUserTicketCollection(acct.address)
        /** ------------- End ------------------------------------------------ */

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

        /* --- Configure a ScopedFTProvider - Start ------------- */
        //
        // Issue and store bridge-dedicated Provider Capability in storage if necessary
        if acct.storage.type(at: FlowEVMBridgeConfig.providerCapabilityStoragePath) == nil {
            let providerCap = acct.capabilities.storage
                .issue<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>(/storage/flowTokenVault)
            acct.storage.save(providerCap, to: FlowEVMBridgeConfig.providerCapabilityStoragePath)
        }
        let providerCapCopy = acct.storage
            .copy<Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>>(
                from: FlowEVMBridgeConfig.providerCapabilityStoragePath
            ) ?? panic("Invalid FungibleToken Provider Capability found in storage at path "
                .concat(FlowEVMBridgeConfig.providerCapabilityStoragePath.toString()))
        let providerFilter = ScopedFTProviders.AllowanceFilter(cost)
        self.scopedProvider <- ScopedFTProviders.createScopedFTProvider(
            provider: providerCapCopy,
            filters: [ providerFilter ],
            expiration: getCurrentBlock().timestamp + 1.0
        )
        /* --- Configure a ScopedFTProvider --- End ------------- */

        /** ------------- Prepare the pool reference - Start -------------- */
        self.pool = FixesTradablePool.borrowTradablePool(coinAddress)
            ?? panic("Could not get the Pool Resource!")
        /** ------------- End ----------------------------------------------- */

        /** ------------- Prepare the token recipient - Start -------------- */
        let tokenVaultData = self.pool.getTokenVaultData()
        // ensure storage path
        if acct.storage.borrow<&AnyResource>(from: tokenVaultData.storagePath) == nil {
            // save the empty vault
            acct.storage.save(<- tokenVaultData.createEmptyVault(), to: tokenVaultData.storagePath)
        }

        // save the public capability to the stored vault
        if acct.capabilities.get<&{FungibleToken.Receiver}>(tokenVaultData.receiverPath).borrow() == nil {
            acct.capabilities.unpublish(tokenVaultData.receiverPath)
            // Create a public capability to the stored Vault that exposes
            // the `deposit` method through the `Receiver` interface.
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&{FungibleToken.Receiver}>(tokenVaultData.storagePath),
                at: tokenVaultData.receiverPath
            )
        }

        if acct.capabilities.get<&{FungibleToken.Vault, FixesFungibleTokenInterface.Vault}>(tokenVaultData.metadataPath).borrow() == nil {
            acct.capabilities.unpublish(tokenVaultData.metadataPath)
            // Create a public capability to the stored Vault that only exposes
            // the `balance` field and the `resolveView` method through the `Balance` interface
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&{FungibleToken.Vault, FixesFungibleTokenInterface.Vault}>(tokenVaultData.storagePath),
                at: tokenVaultData.metadataPath
            )
        }

        self.recipient = acct.capabilities.get<&{FungibleToken.Receiver}>(tokenVaultData.receiverPath)
            .borrow()
            ?? panic("Could not borrow a reference to the recipient's Receiver!")
        /** ------------- End ----------------------------------------------- */
    }

    execute {
        // But token with tickets
        FGameLotteryFactory.buyCoinWithLotteryTicket(
            coinAddress,
            flowProvider: &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
            flowAmount: cost,
            ftReceiver: self.recipient,
            ticketRecipient: self.ticketRecipient,
            inscriptionStore: self.inscriptionStore,
        )
        destroy self.scopedProvider
    }
}
