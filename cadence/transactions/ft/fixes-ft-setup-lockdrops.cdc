import "FungibleToken"
import "FlowToken"
import "stFlowToken"
// Fixes Imports
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20FTShared"
import "FungibleTokenManager"
import "FixesTokenLockDrops"

// This transaction is used to setup lockdrop pool for a token
// - Parameters:
//   - symbol: The symbol of the token
//   - mintableSupply: The total supply of the token
//   - lockingTickType: [0, 1, 2] The type of the locking tick, 0 = $FLOW, 1 = fixes, 2 = $stFlow
//   - activateAt: The time when the pool will be activated
//   - deprecatedAt: The time when the pool will be deprecated if not fully locked
transaction(
    symbol: String,
    mintableSupply: UFix64,
    lockingTickType: UInt8,
    lockingRewardMultiply: UFix64,
    activateAt: UFix64?,
    deprecatedAt: UFix64?,

) {
    let tickerName: String
    let ins: &Fixes.Inscription

    prepare(acct: AuthAccount) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        // Get a reference to the signer's stored vault
        let flowVaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        self.tickerName = "$".concat(symbol)

        /** ------------- Create the Inscription 2 - Start ------------- */
        let fields: {String: String} = {}
        fields["supply"] = mintableSupply.toString()
        fields["lockingTick"] = getLockingTickName(lockingTickType)
        if activateAt != nil {
            fields["activateAt"] = activateAt!.toString()
        }
        if deprecatedAt != nil {
            fields["deprecatedAt"] = deprecatedAt!.toString()
        }
        let tradablePoolInsDataStr = FixesInscriptionFactory.buildPureExecuting(
            tick: self.tickerName,
            usage: "setup-lockdrop",
            fields
        )
        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(tradablePoolInsDataStr)
        // get reserved cost
        let flowToReserve <- (flowVaultRef.withdraw(amount: estimatedReqValue) as! @FlowToken.Vault)
        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            tradablePoolInsDataStr,
            <- flowToReserve,
            store
        )
        // borrow a reference to the new Inscription
        self.ins = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow a reference to the newly created Inscription!")
        /** ------------- End --------------------------------------- */
    }

    pre {
        FungibleTokenManager.isTokenSymbolEnabled(self.tickerName) == true: "Token is already enabled"
    }

    execute {
        FungibleTokenManager.setupLockDropsPool(
            self.ins,
            lockingExchangeRates: FixesTokenLockDrops.getDefaultExchangeRatesPlan(lockingRewardMultiply)
        )
    }
}

access(all)
fun getLockingTickName(_ lockingTickType: UInt8): String {
    if lockingTickType == 0 {
        return ""
    } else if lockingTickType == 1 {
        return FRC20FTShared.getPlatformUtilityTickerName()
    } else if lockingTickType == 2 {
        return "@".concat(Type<@stFlowToken.Vault>().identifier)
    }
    panic("Invalid locking tick type")
}
