import "FungibleToken"
import "FlowToken"
// Fixes Imports
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FixesTokenAirDrops"

transaction(
    symbol: String,
    claimables: {Address: UFix64}
) {
    let ins: auth(Fixes.Extractable) &Fixes.Inscription
    let tickerName: String
    let poolAddress: Address

    prepare(acct: auth(Storage, Capabilities) &Account) {
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

        // Get a reference to the signer's stored vault
        let flowVaultRef = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        self.tickerName = "$".concat(symbol)

        /** ------------- Create the Inscription - Start ------------- */
        let fields: {String: String} = {}
        let dataStr = FixesInscriptionFactory.buildPureExecuting(
            tick: self.tickerName,
            usage: "set-claimables",
            fields
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

        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        self.poolAddress = acctsPool.getFTContractAddress(self.tickerName)
            ?? panic("Could not get the FRC20 contract address!")
     }

     pre {
        claimables.length > 0: "Claimables must have at least one entry!"
     }

    execute {
        // Set the claimables
        let pool = FixesTokenAirDrops.borrowAirdropPool(self.poolAddress)
            ?? panic("Could not get the Airdrop Pool!")
        pool.setClaimableDict(self.ins, claimables: claimables)
    }
}
