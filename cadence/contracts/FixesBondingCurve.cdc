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

    // Event that is emitted when the subject fee percentage is changed.
    access(all) event LiquidityPoolSubjectFeePercentageChanged(subject: Address, subjectFeePercentage: UFix64)

    // Event that is emitted when a user buys or sells tokens.
    access(all) event Trade(trader: Address, isBuy: Bool, subject: Address, shareAmount: UFix64, flowAmount: UFix64, protocolFee: UFix64, subjectFee: UFix64, supply: UFix64)

    /// -------- Resources and Interfaces --------

    /// The curve interface.
    ///
    access(all) struct interface CurveInterface {
        access(all)
        view fun calculatePrice(supply: UFix64, amount: UFix64): UFix64
    }

    /// The curve for SmallSupply (<= 10000)
    /// This formula is used to calculate the price of a token based on the token's supply.
    /// Inspired by FriendTech: https://basescan.org/address/0xcf205808ed36593aa40a44f10c7f7c2f67d4a4d4#code
    /// Formula: y = (x - 1) * x * (2 * (x - 1) + 1) / 6
    ///
    access(all) struct BondingCurveForSmallSupply: CurveInterface {
        access(all)
        view fun calculatePrice(supply: UFix64, amount: UFix64): UFix64 {
            let scaledX = SwapConfig.UFix64ToScaledUInt256(supply)
            let scaledDeltaX = SwapConfig.UFix64ToScaledUInt256(amount)
            let y1: UInt256 = scaledX == 0
                ? 0
                : (scaledX - 1) * (scaledX) / SwapConfig.scaleFactor * (2 * (scaledX - 1) + 1) / 6 / SwapConfig.scaleFactor
            let y2: UInt256 = scaledX == 0 && scaledDeltaX == 1
                ? 0
                : (scaledX - 1 + scaledDeltaX) * (scaledX + scaledDeltaX) / SwapConfig.scaleFactor * (2 * (scaledX - 1 + scaledDeltaX) + 1) / 6 / SwapConfig.scaleFactor
            let summation = y2 - y1
            return SwapConfig.ScaledUInt256ToUFix64(summation / 16000)
        }
    }

    /// The curve for LargeSupply (21_000_000 ~ 1_000_000_000)
    /// This formula is used to calculate the price of a token based on the token's supply.
    /// Inspired by FriendTech: https://basescan.org/address/0xcf205808ed36593aa40a44f10c7f7c2f67d4a4d4#code
    /// Formula: y = (x - 1) * x * (2 * (x - 1) + 1) / 6
    ///
    access(all) struct BondingCurveForLargeSupply: CurveInterface {
        access(all)
        view fun calculatePrice(supply: UFix64, amount: UFix64): UFix64 {
            // TODO
            return 0.0
        }
    }

    /// The liquidity pool interface.
    ///
    access(all) resource interface LiquidityPoolInterface {
        /// Get the subject address
        access(all)
        view fun getSubjectAddress(): Address {
            return self.owner?.address ?? panic("The owner is missing")
        }
        /// Get the curve type
        access(all)
        view fun getCurveType(): Type
    }

    /// The liquidity pool admin interface.
    ///
    access(all) resource interface LiquidityPoolAdmin {
        // The admin can set the subject fee percentage
        //
        access(all)
        fun setSubjectFeePercentage(_ subjectFeePerc: UFix64)
    }

    /// The liquidity pool resource.
    ///
    access(all) resource LiquidityPool: LiquidityPoolInterface, LiquidityPoolAdmin {
        access(self)
        let minter: Capability<&AnyResource{FixesFungibleTokenInterface.IMinter}>
        access(self)
        let curve: {CurveInterface}
        access(contract)
        var subjectFeePercentage: UFix64

        init(
            _ minterCap: Capability<&AnyResource{FixesFungibleTokenInterface.IMinter}>,
            _ curve: {CurveInterface},
            _ subjectFeePerc: UFix64?
        ) {
            pre {
                minterCap.check(): "The minter capability is missing"
            }
            self.minter = minterCap
            self.curve = curve
            self.subjectFeePercentage = subjectFeePerc ?? 0.0
        }

        // ------ Implement LiquidityPoolInterface -----

        /// Get the curve type
        ///
        access(all)
        view fun getCurveType(): Type {
            return self.curve.getType()
        }

        // ----- Implement LiquidityPoolAdmin -----

        // The admin can set the subject fee percentage
        //
        access(all)
        fun setSubjectFeePercentage(_ subjectFeePerc: UFix64) {
            self.subjectFeePercentage = subjectFeePerc

            // Emit the event
            emit LiquidityPoolSubjectFeePercentageChanged(
                subject: self.getSubjectAddress(),
                subjectFeePercentage: subjectFeePerc
            )
        }

        // ----- Internal Methods -----

        access(self)
        fun _borrowMinter(): &AnyResource{FixesFungibleTokenInterface.IMinter} {
            return self.minter.borrow() ?? panic("The minter capability is missing")
        }
    }

    /// ------ Public Methods ------

    /// Create a new tradable liquidity pool(bonding curve) resource
    ///
    access(all)
    fun createTradableLiquidityPool(
        ins: &Fixes.Inscription,
        _ minterCap: Capability<&AnyResource{FixesFungibleTokenInterface.IMinter}>,
    ): @LiquidityPool {
        return <- create LiquidityPool(minterCap)
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
