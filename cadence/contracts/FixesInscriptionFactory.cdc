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

    // Basic FRC20 Inscription

    access(all)
    fun buildMintFRC20(
        tick: String,
        amt: UFix64,
    ): String {
        return "op=mint,tick=".concat(tick).concat(",amt=").concat(amt.toString())
    }

    access(all)
    fun buildBurnFRC20(
        tick: String,
        amt: UFix64,
    ): String {
        return "op=burn,tick=".concat(tick).concat(",amt=").concat(amt.toString())
    }

    access(all)
    fun buildDeployFRC20(
        tick: String,
        max: UFix64,
        limit: UFix64,
        burnable: Bool,
    ): String {
        return "op=deploy,tick=".concat(tick)
            .concat(",max=").concat(max.toString())
            .concat(",lim=").concat(limit.toString())
            .concat(",burnable=").concat(burnable ? "1" : "0")
    }

    access(all)
    fun buildTransferFRC20(
        tick: String,
        to: Address,
        amt: UFix64,
    ): String {
        return "op=transfer,tick=".concat(tick)
            .concat(",amt=").concat(amt.toString())
            .concat(",to=").concat(to.toString())
    }

    // Market FRC20 Inscription

    access(all)
    fun buildMarketEnable(
        tick: String,
    ): String {
        return "op=enable-market,tick=".concat(tick)
    }

    access(all)
    fun buildMarketListBuyNow(
        tick: String,
        amount: UFix64,
        price: UFix64,
    ): String {
        return "op=list-buynow,tick=".concat(tick)
            .concat(",amt=").concat(amount.toString())
            .concat(",price=").concat(price.toString())
    }

    access(all)
    fun buildMarketListSellNow(
        tick: String,
        amount: UFix64,
        price: UFix64,
    ): String {
        return "op=list-sellnow,tick=".concat(tick)
            .concat(",amt=").concat(amount.toString())
            .concat(",price=").concat(price.toString())
    }

    access(all)
    fun buildMarketTakeBuyNow(
        tick: String,
        amount: UFix64,
    ): String {
        return "op=list-take-buynow,tick=".concat(tick)
            .concat(",amt=").concat(amount.toString())
    }

    access(all)
    fun buildMarketTakeSellNow(
        tick: String,
        amount: UFix64,
    ): String {
        return "op=list-take-sellnow,tick=".concat(tick)
            .concat(",amt=").concat(amount.toString())
    }

    // Staking FRC20 Inscription

    access(all)
    fun buildStakeDonate(
        tick: String?,
        amount: UFix64?,
    ): String {
        var dataStr = "op=withdraw,usage=donate"
        if tick != nil && amount != nil {
            dataStr = dataStr
                .concat(",tick=").concat(tick!)
                .concat(",amt=").concat(amount!.toString())
        }
        return dataStr
    }

    access(all)
    fun buildStakeWithdraw(
        tick: String,
        amount: UFix64,
    ): String {
        return "op=withdraw,tick=".concat(tick)
            .concat(",amt=").concat(amount.toString())
            .concat(",usage=staking")
    }

    access(all)
    fun buildStakeDeposit(
        tick: String,
    ): String {
        return "op=deposit,tick=".concat(tick)
    }
}
