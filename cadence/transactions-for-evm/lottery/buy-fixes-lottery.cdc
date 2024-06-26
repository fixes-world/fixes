// Thirdparty imports
import "FungibleToken"
import "FlowToken"
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
    let store: &Fixes.InscriptionsStore
    let flowCost: @FlowToken.Vault

    prepare(signer: AuthAccount) {
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
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        self.store = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        /** ------------- Initialize TicketCollection - Start ---------------- */
        // If the user doesn't have a TicketCollection yet, create one
        if acct.borrow<&FGameLottery.TicketCollection>(from: FGameLottery.userCollectionStoragePath) == nil {
            acct.save(<- FGameLottery.createTicketCollection(), to: FGameLottery.userCollectionStoragePath)
        }
        // Link public capability to the account
        // @deprecated after Cadence 1.0
        if acct
            .getCapability<&FGameLottery.TicketCollection{FGameLottery.TicketCollectionPublic}>(FGameLottery.userCollectionPublicPath)
            .borrow() == nil {
            acct.unlink(FGameLottery.userCollectionPublicPath)
            acct.link<&FGameLottery.TicketCollection{FGameLottery.TicketCollectionPublic}>(
                FGameLottery.userCollectionPublicPath,
                target: FGameLottery.userCollectionStoragePath
            )
        }
        /** ------------- End ------------------------------------------------ */

        let powerupType = FGameLotteryFactory.PowerUpType(rawValue: powerupLv) ?? panic("Invalid powerup level")

        let estimateFlowCost = forFlow
            ? FGameLotteryFactory.getFIXESMintingLotteryFlowCost(ticketAmt, powerupType, withMinting)
            : FGameLotteryFactory.getFIXESLotteryFlowCost(ticketAmt, powerupType, acct.address)

        // Get a reference to the signer's stored vault
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")
        self.flowCost <- vaultRef.withdraw(amount: estimateFlowCost) as! @FlowToken.Vault
    }

    execute {
        // Get the user's TicketCollection capability
        let ticketCollectionCap = FGameLottery.getUserTicketCollection(self.address)
        assert(
            ticketCollectionCap.borrow() != nil,
            message: "Could not borrow a reference to the user's TicketCollection!"
        )

        // Purchase the lottery
        var restVault: @FlowToken.Vault? <- nil
        if forFlow {
            restVault <-! FGameLotteryFactory.buyFIXESMintingLottery(
                flowVault: <- self.flowCost,
                ticketAmount: ticketAmt,
                powerup: FGameLotteryFactory.PowerUpType(rawValue: powerupLv) ?? panic("Invalid powerup level"),
                withMinting: withMinting,
                recipient: ticketCollectionCap,
                inscriptionStore: self.store
            )
        } else {
            restVault <-! FGameLotteryFactory.buyFIXESLottery(
                flowVault: <- self.flowCost,
                ticketAmount: ticketAmt,
                powerup: FGameLotteryFactory.PowerUpType(rawValue: powerupLv) ?? panic("Invalid powerup level"),
                recipient: ticketCollectionCap,
                inscriptionStore: self.store
            )
        }

        // If there's any remaining Flow in the vault, deposit it into the user's FlowToken receiver
        if restVault?.balance! > 0.0 {
            let flowTokenReceiver = Fixes.borrowFlowTokenReceiver(self.address)
                ?? panic("Could not borrow a reference to the FlowToken Receiver!")
            flowTokenReceiver.deposit(from: <- restVault!)
        } else {
            destroy restVault
        }

        log("FIXES Lottery purchased!")
    }
}
