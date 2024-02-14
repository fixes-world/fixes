/**
> Author: FIXeS World <https://fixes.world/>

# FixesInscriptionFactory

This contract is a helper factory contract to create Fixes Inscriptions.

*/

import "FlowToken"
// Fixes Imports
import "Fixes"

access(all) contract FixesInscriptionFactory {

    /* --- General Private Methods --- */

    /// This is the general factory method to create a fixes inscription
    ///
    access(all)
    fun createFrc20Inscription(
        _ dataStr: String,
        _ costReserve: @FlowToken.Vault
    ): @Fixes.Inscription {
        return <- Fixes.createInscription(
            value: <- costReserve,
            mimeType: "text/plain",
            metadata: dataStr.utf8,
            metaProtocol: "frc20",
            encoding: nil,
            parentId: nil
        )
    }

    /// Estimate inscribing cost
    ///
    access(all)
    fun estimateFrc20InsribeCost(
        _ dataStr: String
    ): UFix64 {
        // estimate the required storage
        return Fixes.estimateValue(
            index: Fixes.totalInscriptions,
            mimeType: "text/plain",
            data: dataStr.utf8,
            protocol: "frc20",
            encoding: nil
        )
    }

    /* --- Public Methods --- */

    /// create a standard mint frc20 inscription
    ///
    access(all)
    fun buildMintFRC20(
        tick: String,
        amt: UFix64,
    ): String {
        return "op=mint,tick=".concat(tick).concat(",amt=").concat(amt.toString())
    }
}
