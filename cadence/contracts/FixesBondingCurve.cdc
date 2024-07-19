/**

> Author: FIXeS World <https://fixes.world/>

# FixesBondingCurve

This is a bonding curve contract that uses a Quadratic curve to calculate the price of a token based on the token's supply.

*/
// Third-party dependencies
import "SwapConfig"

/// The bonding curve contract.
///
access(all) contract FixesBondingCurve {

    /// -------- Resources and Interfaces --------

    /// The curve interface.
    ///
    access(all) struct interface CurveInterface {
        access(all)
        view fun getFreeAmount(): UFix64 { return 0.0 }
        access(all)
        view fun calculatePrice(supply: UFix64, amount: UFix64): UFix64
        access(all)
        view fun calculateAmount(supply: UFix64, cost: UFix64): UFix64
        /// Calculate the unit price of the token
        access(all)
        view fun calculateUnitPrice(supply: UFix64): UFix64 {
            let freeAmount = self.getFreeAmount()
            let restFreeAmount = freeAmount.saturatingSubtract(supply)
            return self.calculatePrice(supply: supply, amount: restFreeAmount + 1.0)
        }
    }

    /// The Quadratic curve implementation.
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
    access(all) struct Quadratic: CurveInterface {
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
            assert(
                max > 0,
                message: "Max supply must be greater than 0"
            )
            self.priceCoefficient = max / 2 / SwapConfig.scaleFactor * SwapConfig.sqrt(max) / SwapConfig.sqrt(SwapConfig.scaleFactor)
        }

        /// Get the free amount
        ///
        access(all)
        view fun getFreeAmount(): UFix64 { return SwapConfig.ScaledUInt256ToUFix64(self.freeScaledAmount) }

        /// Get the price of the token based on the supply and amount
        ///
        access(all)
        view fun calculatePrice(supply: UFix64, amount: UFix64): UFix64 {
            // avoid useless calculation
            if amount == 0.0 {
                return 0.0
            }

            let scaledX = SwapConfig.UFix64ToScaledUInt256(supply)
            let scaledDeltaX = SwapConfig.UFix64ToScaledUInt256(amount)
            let ufix64Max = SwapConfig.UFix64ToScaledUInt256(UFix64.max)
            // calculate the sum of squares
            let x0 = scaledX.saturatingSubtract(self.freeScaledAmount)
            let sum0: UInt256 = scaledX < self.freeScaledAmount
                ? 0
                : x0 * (x0 + 1) / SwapConfig.scaleFactor * (2 * x0 + 1) / 6 / SwapConfig.scaleFactor
            // calculate the sum of squares after adding the amount
            let x1 = scaledX.saturatingAdd(scaledDeltaX).saturatingSubtract(self.freeScaledAmount)
            let sum1: UInt256 = scaledX + scaledDeltaX <= self.freeScaledAmount
                ? 0
                : x1 * (x1 + 1) / SwapConfig.scaleFactor * (2 * x1 + 1) / 6 / SwapConfig.scaleFactor
            let summation = sum1 - sum0
            // free tokens
            if summation == 0 {
                return 0.0
            }
            let fixedPriceCoefficient = self.priceCoefficient / 250000 * self.priceCoefficient
            let price = summation / fixedPriceCoefficient
            if price > ufix64Max {
                return UFix64.max
            }
            let ret = SwapConfig.ScaledUInt256ToUFix64(price)
            // set the minimum price for none-free tokens
            if ret == 0.0 {
                return 0.00000001
            }
            return ret
        }

        /// Calculate the amount of tokens that can be bought with the given cost
        ///
        access(all)
        view fun calculateAmount(supply: UFix64, cost: UFix64): UFix64 {
            // avoid useless calculation
            if cost == 0.0 {
                return 0.0
            }

            let freeAmount = self.getFreeAmount()
            let restFreeAmount = freeAmount.saturatingSubtract(supply)
            var supplyOnePrice = self.calculatePrice(supply: supply, amount: restFreeAmount + 1.0)
            if supplyOnePrice == 0.0 {
                supplyOnePrice = 0.00000001
            }

            let minH = 0.01
            var low = restFreeAmount
            var high = restFreeAmount + cost / supplyOnePrice
            var finalAmount = low.saturatingAdd(high).saturatingMultiply(0.5)

            var calcCost = self.calculatePrice(supply: supply, amount: finalAmount)
            // binary search
            while calcCost > cost.saturatingAdd(minH) || calcCost < cost.saturatingSubtract(minH) {
                if calcCost > cost {
                    high = finalAmount
                } else {
                    low = finalAmount
                }
                finalAmount = low.saturatingAdd(high) * 0.5
                calcCost = self.calculatePrice(supply: supply, amount: finalAmount)
            }
            return finalAmount
        }
    }
}
