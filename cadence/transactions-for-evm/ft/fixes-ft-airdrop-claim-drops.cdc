import "FungibleToken"
import "FlowToken"
import "ViewResolver"
// Fixes Imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FixesTokenAirDrops"
import "EVMAgent"

transaction(
    symbol: String,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {

    let ins: auth(Fixes.Extractable) &Fixes.Inscription
    let pool: &FixesTokenAirDrops.AirdropPool
    let recipient: &{FungibleToken.Receiver}

    prepare(signer: auth(Storage, Capabilities) &Account) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "fixes-ft-airdrop-claim-drops(String)",
            params: [symbol],
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

        let tickerName = "$".concat(symbol)

        /** ------------- Prepare the pool reference - Start -------------- */
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        let tokenFTAddr = acctsPool.getFTContractAddress(tickerName)
            ?? panic("Could not get the Fungible Token Address!")
        self.pool = FixesTokenAirDrops.borrowAirdropPool(tokenFTAddr)
            ?? panic("Could not get the Pool Resource!")
        /** ------------- End ----------------------------------------------- */

        assert(
            self.pool.getClaimableTokenAmount(acct.address) > 0.0,
            message: "No claimable tokens available!"
        )

        /** ------------- Prepare the token recipient - Start -------------- */
        let tokenVaultData = self.pool.getTokenVaultData()
        // ensure storage path
        if acct.storage.borrow<&AnyResource>(from: tokenVaultData.storagePath) == nil {
            // save the empty vault
            acct.storage.save(<- tokenVaultData.createEmptyVault(), to: tokenVaultData.storagePath)

            // save the public capability to the stored vault
            // Create a public capability to the stored Vault that exposes
            // the `deposit` method through the `Receiver` interface.
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&{FungibleToken.Receiver}>(tokenVaultData.storagePath),
                at: tokenVaultData.receiverPath
            )
            // Create a public capability to the stored Vault that only exposes
            // the `balance` field and the `resolveView` method through the `Balance` interface
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&{FungibleToken.Vault}>(tokenVaultData.storagePath),
                at: tokenVaultData.metadataPath
            )
        }

        self.recipient = acct.capabilities.get<&{FungibleToken.Receiver}>(tokenVaultData.receiverPath)
            .borrow()
            ?? panic("Could not borrow a reference to the recipient's Receiver!")
        /** ------------- End ----------------------------------------------- */

        // Get a reference to the signer's stored vault
        let flowVaultRef = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        /** ------------- Create the Inscription - Start ------------- */
        var dataStr = FixesInscriptionFactory.buildPureExecuting(
            tick: tickerName,
            usage: "init",
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
        self.pool.claimDrops(self.ins, recipient: self.recipient)
    }
}
