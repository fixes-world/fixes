import "FungibleToken"
import "MetadataViews"
import "ViewResolver"
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

transaction(
    symbol: String,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    let ins: &Fixes.Inscription
    let pool: &FixesTokenLockDrops.DropsPool{FixesTokenLockDrops.DropsPoolPublic, FixesFungibleTokenInterface.IMinterHolder}
    let recipient: &{FungibleToken.Receiver}?

    prepare(signer: AuthAccount) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "fixes-ft-lockdrop-claim-unlocked-token(String)",
            params: [symbol],
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

        let tickerName = "$".concat(symbol)

        /** ------------- Prepare the pool reference - Start -------------- */
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        let tokenFTAddr = acctsPool.getFTContractAddress(tickerName)
            ?? panic("Could not get the Fungible Token Address!")
        self.pool = FixesTokenLockDrops.borrowDropsPool(tokenFTAddr)
            ?? panic("Could not get the Pool Resource!")
        /** ------------- End ----------------------------------------------- */

        let lockingCenter = FixesTokenLockDrops.borrowLockingCenter()
        assert(
            lockingCenter.hasUnlockedEntries(tokenFTAddr, acct.address),
            message: "No unlocked entries found!"
        )

        /** ------------- Prepare the recipient reference - Start -------------- */
        let lockingTickerName = self.pool.getLockingTokenTicker()
        let lockingType = FixesTokenLockDrops.getLockingTickType(lockingTickerName)

        if lockingType != FixesTokenLockDrops.SupportedLockingTick.fixesFRC20Token {
            // the locking assets are managed by the vault
            let recieverPath = lockingType == FixesTokenLockDrops.SupportedLockingTick.FlowToken
                ? /public/flowTokenReceiver
                : stFlowToken.tokenReceiverPath
            self.recipient = acct.getCapability<&{FungibleToken.Receiver}>(recieverPath)
                .borrow() ?? panic("Could not borrow a reference to the recipient's Receiver!")
        } else {
            self.recipient = nil
        }
        /** ------------- End ----------------------------------------------- */

        // Get a reference to the signer's stored vault
        let flowVaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        /** ------------- Create the Inscription - Start ------------- */
        var dataStr = FixesInscriptionFactory.buildPureExecuting(
            tick: tickerName,
            usage: "claim-unlocked",
            {}
        )
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

    pre {
        self.pool.isClaimable(): "The pool is not claimable!"
    }

    execute {
        self.pool.claimUnlockedTokens(self.ins, recipient: self.recipient)
    }
}
