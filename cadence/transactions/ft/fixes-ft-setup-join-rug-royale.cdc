import "FungibleToken"
import "FlowToken"
import "stFlowToken"
// Fixes Imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FixesTradablePool"
import "FGameRugRoyale"

transaction(
    symbol: String,
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

        /** ------------- Create the Inscription - Start ------------ */
        let dataStr = FixesInscriptionFactory.buildPureExecuting(
            tick: self.tickerName,
            usage: "join-rug-royale",
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

    execute {
        // Get the liquidity cap capability
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        let addr = acctsPool.getFTContractAddress(self.tickerName)
            ?? panic("Could not get the FRC20 contract address!")
        // Get the liquidity cap capability
        let liquidityCap = getAccount(addr)
            .getCapability<&{FixesFungibleTokenInterface.LiquidityHolder}>(FixesTradablePool.getLiquidityPoolPublicPath())

        assert(liquidityCap.check(), message: "Failed to get the liquidity capability!")

        let gameCenter = FGameRugRoyale.borrowGameCenter()
        gameCenter.joinGame(ins: self.ins, liquidityCap)
    }
}
