import "FungibleToken"
import "FlowToken"
import "stFlowToken"
// Fixes Imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FixesTokenLockDrops"
import "EVMAgent"

// - Parameters:
//   - symbol: The symbol of the token
//   - lockingTickType: [0, 1, 2] The type of the locking tick, 0 = $FLOW, 1 = $stFlow, 2 = fixes
//   - lockingPeriod: The period of the lock in seconds
//   - lockingAmount: The amount of the token to lock
transaction(
    symbol: String,
    lockingTickType: UInt8,
    lockingPeriod: UFix64,
    lockingAmount: UFix64,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    let tickerName: String
    let ins: &Fixes.Inscription
    let pool: &FixesTokenLockDrops.DropsPool{FixesTokenLockDrops.DropsPoolPublic, FixesFungibleTokenInterface.IMinterHolder}
    let lockingVault: @FungibleToken.Vault?

    prepare(signer: AuthAccount) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "fixes-ft-lockdrop-lock-in-tokens(String|UInt8|UFix64|UFix64)",
            params: [symbol, lockingTickType.toString(), lockingPeriod.toString(), lockingAmount.toString()],
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp
        )
        /** ------------- EVMAgency: End --------------------------------------- */

        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        self.tickerName = "$".concat(symbol)

        /** ------------- Prepare the pool reference - Start -------------- */
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        let tokenFTAddr = acctsPool.getFTContractAddress(self.tickerName)
            ?? panic("Could not get the Fungible Token Address!")
        self.pool = FixesTokenLockDrops.borrowDropsPool(tokenFTAddr)
            ?? panic("Could not get the Pool Resource!")
        /** ------------- End ----------------------------------------------- */

        let lockType = FixesTokenLockDrops.SupportedLockingTick(rawValue: lockingTickType)
            ?? panic("Invalid locking tick type")
        // check period
        let periodRate = self.pool.getExchangeRate(lockingPeriod)
        assert(periodRate > 0.0, message: "Invalid locking period")

        // Get a reference to the signer's stored vault
        let flowVaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        /** ------------- Create the Inscription - Start ------------- */
        var dataStr = ""
        // build different data string based on the locking type
        if lockType != FixesTokenLockDrops.SupportedLockingTick.fixesFRC20Token {
            dataStr = FixesInscriptionFactory.buildPureExecuting(
                tick: self.tickerName,
                usage: "lock-drop",
                {}
            )
            // the locking assets are managed by the vault
            if lockType == FixesTokenLockDrops.SupportedLockingTick.FlowToken {
                self.lockingVault <- flowVaultRef.withdraw(amount: lockingAmount)
            } else {
                let stFlowVaultRef = acct.borrow<&stFlowToken.Vault>(from: stFlowToken.tokenVaultPath)
                    ?? panic("Could not borrow reference to the owner's stFlow Vault!")
                self.lockingVault <- stFlowVaultRef.withdraw(amount: lockingAmount)
            }
        } else {
            let tick = FixesTokenLockDrops.getLockingTickerName(lockType)
            // all locking assets are managed by Fixes Inscription
            dataStr = FixesInscriptionFactory.buildWithdraw(
                tick: tick,
                amount: lockingAmount,
                usage: "lock"
            )
            self.lockingVault <- nil
        }

        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)
        // get reserved cost
        let flowToReserve <- (flowVaultRef.withdraw(amount: estimatedReqValue) as! @FlowToken.Vault)
        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            dataStr,
            <- flowToReserve,
            store
        )
        // borrow a reference to the new Inscription
        self.ins = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow a reference to the newly created Inscription!")
        /** ------------- End --------------------------------------- */
    }

    execute {
        self.pool.lockAndMint(self.ins, lockingPeriod: lockingPeriod, lockingVault: <- self.lockingVault)
    }
}
