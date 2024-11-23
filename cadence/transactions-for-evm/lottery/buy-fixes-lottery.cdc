// Thirdparty imports
import "FungibleToken"
import "FlowToken"
import "ScopedFTProviders"
import "FlowEVMBridgeConfig"
// Fixes Imports
import "Fixes"
import "FGameLottery"
import "FGameLotteryFactory"
import "EVMAgent"

transaction(
    ticketAmt: UInt64,
    powerupLv: UInt8,
    forFlow: Bool,
    withMinting: Bool,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    let address: Address
    let store: auth(Fixes.Manage) &Fixes.InscriptionsStore
    let scopedProvider: @ScopedFTProviders.ScopedFTProvider

    prepare(signer: auth(Storage, Capabilities) &Account) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "buy-fixes-lottery(UInt64|UInt8|Bool|Bool)",
            params: [ticketAmt.toString(), powerupLv.toString(), forFlow ? "true" : "false", withMinting ? "true" : "false"],
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp
        )
        /** ------------- EVMAgency: End --------------------------------------- */

        self.address = acct.address

        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.storage.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        self.store = acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

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
        /** ------------- End ------------------------------------------------ */

        let powerupType = FGameLotteryFactory.PowerUpType(rawValue: powerupLv) ?? panic("Invalid powerup level")

        let estimateFlowCost = forFlow
            ? FGameLotteryFactory.getFIXESMintingLotteryFlowCost(ticketAmt, powerupType, withMinting)
            : FGameLotteryFactory.getFIXESLotteryFlowCost(ticketAmt, powerupType, acct.address)

        /* --- Configure a ScopedFTProvider --- */
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
        let providerFilter = ScopedFTProviders.AllowanceFilter(estimateFlowCost)
        self.scopedProvider <- ScopedFTProviders.createScopedFTProvider(
            provider: providerCapCopy,
            filters: [ providerFilter ],
            expiration: getCurrentBlock().timestamp + 1.0
        )
    }

    execute {
        // Get the user's TicketCollection capability
        let ticketCollectionCap = FGameLottery.getUserTicketCollection(self.address)
        assert(
            ticketCollectionCap.borrow() != nil,
            message: "Could not borrow a reference to the user's TicketCollection!"
        )

        // Purchase the lottery
        if forFlow {
            FGameLotteryFactory.buyFIXESMintingLottery(
                flowProvider:  &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
                ticketAmount: ticketAmt,
                powerup: FGameLotteryFactory.PowerUpType(rawValue: powerupLv) ?? panic("Invalid powerup level"),
                withMinting: withMinting,
                recipient: ticketCollectionCap,
                inscriptionStore: self.store
            )
        } else {
            FGameLotteryFactory.buyFIXESLottery(
                flowProvider: &self.scopedProvider as auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
                ticketAmount: ticketAmt,
                powerup: FGameLotteryFactory.PowerUpType(rawValue: powerupLv) ?? panic("Invalid powerup level"),
                recipient: ticketCollectionCap,
                inscriptionStore: self.store
            )
        }
        destroy self.scopedProvider
        log("FIXES Lottery purchased!")
    }
}
