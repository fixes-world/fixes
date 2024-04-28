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

    // Event that is emitted when the liquidity pool is initialized.
    access(all) event LiquidityPoolInitialized(subject: Address, mintedAmount: UFix64)

    // Event that is emitted when a user buys or sells tokens.
    access(all) event Trade(trader: Address, isBuy: Bool, subject: Address, shareAmount: UFix64, flowAmount: UFix64, protocolFee: UFix64, subjectFee: UFix64, supply: UFix64)

    /// -------- Resources and Interfaces --------

    /// The curve interface.
    ///
    access(all) struct interface CurveInterface {
        access(all)
        view fun calculatePrice(supply: UFix64, amount: UFix64): UFix64
        access(all)
        view fun calculateAmount(supply: UFix64, cost: UFix64): UFix64
    }

    /// The curve for SmallSupply (<= 10000)
    /// This formula is used to calculate the price of a token based on the token's supply.
    /// Inspired by FriendTech: https://basescan.org/address/0xcf205808ed36593aa40a44f10c7f7c2f67d4a4d4#code
    /// Formula:
    ///  - Price = ((CurrentSupply - FreeAmount) * Coefficient)^2
    ///    -> y = x^2
    ///    -> SumY = 1^2 + 2^2 + 3^2 + ... + x^2 = x * (x + 1) * (2 * x + 1) / 6
    ///  - Sum1 -> CurrentSupply < FreeAmount ? 0 : SumY(CurrentSupply - FreeAmount)
    ///  - Sum2 -> CurrentSupply + Amount <= FreeAmount ? 0 : SumY(CurrentSupply - FreeAmount + Amount)
    ///  - BuyPrice = (sum2 - sum1) * Coefficient^2
    ///  Coefficient = Sqrt(1 / (Sqrt(maxSupply) + maxSupply/2))
    ///   -> priceCoefficient = 1 / Coefficient^2 = maxSupply / 2 * Sqrt(maxSupply)
    ///
    access(all) struct BondingCurveQuadratic: CurveInterface {
        access(all)
        let freeScaledAmount: UInt256
        access(all)
        let priceCoefficient: UInt256

        init(
            freeAmount: UFix64?,
            maxSupply: UFix64?
        ) {
            self.freeScaledAmount = SwapConfig.UFix64ToScaledUInt256(freeAmount ?? 0.0)
            let max = SwapConfig.UFix64ToScaledUInt256(maxSupply ?? UFix64.max)
            self.priceCoefficient = max / 2 / SwapConfig.scaleFactor * SwapConfig.sqrt(max) / SwapConfig.sqrt(SwapConfig.scaleFactor)
        }

        /// Get the price of the token based on the supply and amount
        ///
        access(all)
        view fun calculatePrice(supply: UFix64, amount: UFix64): UFix64 {
            let scaledX = SwapConfig.UFix64ToScaledUInt256(supply)
            let scaledDeltaX = SwapConfig.UFix64ToScaledUInt256(amount)
            // calculate the sum of squares
            let x0 = scaledX - self.freeScaledAmount
            let sum0: UInt256 = scaledX < self.freeScaledAmount
                ? 0
                : x0 * (x0 + 1) / SwapConfig.scaleFactor * (2 * x0 + 1) / 6 / SwapConfig.scaleFactor
            // calculate the sum of squares after adding the amount
            let x1 = scaledX - self.freeScaledAmount + scaledDeltaX
            let sum2: UInt256 = scaledX + scaledDeltaX <= self.freeScaledAmount
                ? 0
                : x1 * (x1 + 1) / SwapConfig.scaleFactor * (2 * x1 + 1) / 6 / SwapConfig.scaleFactor
            let summation = sum2 - sum0
            return SwapConfig.ScaledUInt256ToUFix64(summation / self.priceCoefficient)
        }

        /// Calculate the amount of tokens that can be bought with the given cost
        ///
        access(all)
        view fun calculateAmount(supply: UFix64, cost: UFix64): UFix64 {
            let supplyOnePrice = self.calculatePrice(supply: supply, amount: 1.0)
            let maxAmount = cost / supplyOnePrice

            let minH = 0.000001
            var low = 0.0
            var high = maxAmount
            var finalAmount = (low + high) * 0.5
            var calcCost = self.calculatePrice(supply: supply, amount: finalAmount)
            // binary search
            while calcCost > cost + minH || calcCost < cost - minH {
                if calcCost > cost {
                    high = finalAmount
                } else {
                    low = finalAmount
                }
                finalAmount = (low + high) * 0.5
                calcCost = self.calculatePrice(supply: supply, amount: finalAmount)
            }
            return finalAmount
        }
    }

    /// The liquidity pool interface.
    ///
    access(all) resource interface LiquidityPoolInterface {
        access(contract)
        let curve: {CurveInterface}

        // ----- Subject -----

        /// Get the subject address
        access(all)
        view fun getSubjectAddress(): Address {
            return self.owner?.address ?? panic("The owner is missing")
        }

        // ----- Token in the liquidity pool -----

        /// Get the token type
        access(all)
        view fun getTokenType(): Type

        /// Get the max supply of the token
        access(all)
        view fun maxSupply(): UFix64

        /// Get the circulating supply of the token
        access(all)
        view fun getCirculatingSupply(): UFix64

        /// Get the balance of the token in liquidity pool
        access(all)
        view fun getBalance(): UFix64

        // ---- Bonding Curve ----

        /// Get the curve type
        access(all)
        view fun getCurveType(): Type {
            return self.curve.getType()
        }

        /// Get the price of the token based on the supply and amount
        access(all)
        view fun getPrice(supply: UFix64, amount: UFix64): UFix64 {
            return self.curve.calculatePrice(supply: supply, amount: amount)
        }

        /// Calculate the price of buying the token based on the amount
        access(all)
        view fun getBuyPrice(amount: UFix64): UFix64 {
            return self.curve.calculatePrice(supply: self.getCirculatingSupply(), amount: amount)
        }

        /// Calculate the price of selling the token based on the amount
        access(all)
        view fun getSellPrice(amount: UFix64): UFix64 {
            return self.curve.calculatePrice(supply: self.getCirculatingSupply() - amount, amount: amount)
        }

        /// Calculate the amount of tokens that can be bought with the given cost
        access(all)
        view fun calculateAmount(cost: UFix64): UFix64 {
            return self.curve.calculateAmount(supply: self.getCirculatingSupply(), cost: cost)
        }
    }

    /// The liquidity pool admin interface.
    ///
    access(all) resource interface LiquidityPoolAdmin {
        /// Initialize the liquidity pool
        ///
        access(all)
        fun initialize(mintAmount: UFix64?)

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
        let vault: @FungibleToken.Vault
        access(contract)
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

            let minterRef = minterCap.borrow() ?? panic("The minter capability is missing")
            let vaultData = minterRef.getVaultData()
            self.vault <- vaultData.createEmptyVault()
        }

        // @deprecated in Cadence v1.0
        destroy() {
            destroy self.vault
        }

        // ----- Implement LiquidityPoolAdmin -----

        /// Initialize the liquidity pool
        ///
        access(all)
        fun initialize(mintAmount: UFix64?) {
            let toMint = mintAmount ?? 0.0
            // TODO

            emit LiquidityPoolInitialized(
                subject: self.getSubjectAddress(),
                mintedAmount: toMint
            )
        }

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

        // ------ Implement LiquidityPoolInterface -----

        /// Get the token type
        access(all)
        view fun getTokenType(): Type {
            return self.vault.getType()
        }

        /// Get the balance of the token in liquidity pool
        access(all)
        view fun getBalance(): UFix64 {
            return self.vault.balance
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
