/**

> Author: FIXeS World <https://fixes.world/>

# FixesBondingCurve

This is a bonding curve contract that allows users to buy and sell fungible tokens at a price that is determined by a bonding curve algorithm.
The bonding curve algorithm is a mathematical formula that determines the price of a token based on the token's supply.
The bonding curve contract is designed to be used with the FungibleToken contract, which is a standard fungible token
contract that allows users to create and manage fungible tokens.

*/
// Standard dependencies
import "FungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FungibleTokenMetadataViews"
// Third-party dependencies
import "SwapConfig"
import "BlackHole"
// Fixes dependencies
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FRC20FTShared"
import "FRC20AccountsPool"

/// The bonding curve contract.
/// This contract allows users to buy and sell fungible tokens at a price that is determined by a bonding curve algorithm.
///
access(all) contract FixesBondingCurve {

    // ------ Events -------

    // Event that is emitted when a user buys or sells tokens.
    access(all) event Trade( trader: Address, isBuy: Bool, subject: Address, shareAmount: UFix64, flowAmount: UFix64, protocolFee: UFix64, subjectFee: UFix64, supply: UFix64)

    /// -------- Resources and Interfaces --------

    /// The liquidity pool interface.
    ///
    access(all) resource interface LiquidityPoolInterface {

    }

    /// The liquidity pool resource.
    ///
    access(all) resource LiquidityPool: LiquidityPoolInterface {
    }

    /// ------ Public Methods ------

    /// Create a new tradable liquidity pool(bonding curve) resource
    ///
    access(all)
    fun createTradableLiquidityPool(
        ins: &Fixes.Inscription,
        _ minterCap: Capability<&AnyResource{FixesFungibleTokenInterface.IMinter}>,
    ): @LiquidityPool {
        return <- create LiquidityPool()
    }

    /// Get the prefix for the storage paths
    ///
    access(all)
    view fun getPathPrefix(): String {
        return "FixesBondingCurve_".concat(self.account.address.toString()).concat("_")
    }

    /// Get the storage path for the Liquidity Pool
    ///
    access(all)
    view fun getLiquidityPoolStoragePath(): StoragePath {
        let prefix = self.getPathPrefix()
        return StoragePath(identifier: prefix.concat("LiquidityPool"))!
    }

    /// Get the public path for the Liquidity Pool
    ///
    access(all)
    view fun getLiquidityPoolPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("LiquidityPool"))!
    }
}
