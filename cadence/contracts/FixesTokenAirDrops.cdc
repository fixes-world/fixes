/**

> Author: FIXeS World <https://fixes.world/>

# FixesTokenAirDrops

This is an airdrop service contract for the FIXeS token.
It allows users to claim airdrops of the FIXeS token.

*/
import "FungibleToken"
// FIXeS imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FixesTradablePool"
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20AccountsPool"

/// The contract definition
///
access(all) contract FixesTokenAirDropss {

    // ------ Events -------

    // emitted when a new Drops Pool is created
    access(all) event AirdropPoolCreated(
        tokenType: Type,
        tokenSymbol: String,
        minterGrantedAmount: UFix64,
        createdBy: Address
    )

    /// -------- Resources and Interfaces --------

    /// The Airdrop Pool public resource interface
    ///
    access(all) resource interface AirdropPoolPoolPublic {
        // ----- Basics -----

        /// Get the subject address
        access(all)
        view fun getPoolAddress(): Address {
            return self.owner?.address ?? panic("The owner is missing")
        }

        // Borrow the tradable pool
        access(all)
        view fun borrowRelavantTradablePool(): &FixesTradablePool.TradableLiquidityPool{FixesTradablePool.LiquidityPoolInterface}? {
            return FixesTradablePool.borrowTradablePool(self.getPoolAddress())
        }

        /// Check if the pool is claimable
        access(all)
        view fun isClaimable(): Bool

        // ----- Token in the drops pool -----

        /// Get the total claimable amount
        access(all)
        view fun getTotalClaimableAmount(): UFix64

        /// Get the claimable amount
        access(all)
        view fun getClaimableTokenAmount(_ userAddr: Address): UFix64

        // --- Writable ---

        /// Set the claimable amount
        access(all)
        fun setClaimableDict(
            _ ins: &Fixes.Inscription,
            claimables: {Address: UFix64}
        ) {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
            }
            post {
                ins.isExtracted(): "The inscription is not extracted"
            }
        }

        /// Claim drops token
        access(all)
        fun claimDrops(
            _ ins: &Fixes.Inscription,
            recipient: &{FungibleToken.Receiver},
        ) {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
                self.isClaimable(): "You can not claim the token when the pool is not claimable"
            }
            post {
                ins.isExtracted(): "The inscription is not extracted"
            }
        }
    }

    /// The Airdrop Pool resource
    ///
    access(all) resource AirdropPool: AirdropPoolPoolPublic, FixesFungibleTokenInterface.IMinterHolder {
        // The minter of the token
        access(self)
        let minter: @{FixesFungibleTokenInterface.IMinter}
        // Address => Record
        access(self)
        let claimableRecords: {Address: UFix64}
        // Granted amount
        access(self)
        var grantedClaimableAmount: UFix64

        init(
            _ minter: @{FixesFungibleTokenInterface.IMinter},
        ) {
            self.minter <- minter
            self.claimableRecords = {}
            self.grantedClaimableAmount = 0.0
        }

        destroy() {
            destroy self.minter
        }

        // ------ Implment AirdropPoolPoolPublic ------

        /// Check if the pool is claimable
        access(all)
        view fun isClaimable(): Bool {
            // check if tradable pool exists
            // the drops pool is activated only when the tradable pool is initialized but not active
            if let tradablePool = self.borrowRelavantTradablePool() {
                return tradablePool.isInitialized() && !tradablePool.isLocalActive()
            }
            return true
        }

        // ----- Token in the drops pool -----

        /// Get the total claimable amount
        access(all)
        view fun getTotalClaimableAmount(): UFix64 {
            return self.grantedClaimableAmount
        }

        /// Get the claimable amount
        access(all)
        view fun getClaimableTokenAmount(_ userAddr: Address): UFix64 {
            return self.claimableRecords[userAddr] ?? 0.0
        }

        // --- Writable ---

        /// Set the claimable amount
        access(all)
        fun setClaimableDict(
            _ ins: &Fixes.Inscription,
            claimables: {Address: UFix64}
        ) {
            // TODO: implement the claimDrops method
        }

        /// Claim drops token
        access(all)
        fun claimDrops(
            _ ins: &Fixes.Inscription,
            recipient: &{FungibleToken.Receiver},
        ) {
            // TODO: implement the claimDrops method
        }

        // ------ Implment FixesFungibleTokenInterface.IMinterHolder ------

        /// Get the circulating supply of the token
        access(all)
        view fun getCirculatingSupply(): UFix64 {
            if !self.isClaimable() {
                if let tradablePool = self.borrowRelavantTradablePool() {
                    return tradablePool.getTradablePoolCirculatingSupply()
                } else {
                    return self.minter.getTotalSupply()
                }
            } else {
                return self.minter.getTotalSupply()
            }
        }

        /// Borrow the minter
        access(contract)
        view fun borrowMinter(): &AnyResource{FixesFungibleTokenInterface.IMinter} {
            return &self.minter as &AnyResource{FixesFungibleTokenInterface.IMinter}
        }

        // ----- Internal Methods -----
    }


    /// ------ Public Methods ------

    // access(account)

    /// Borrow the Drops Pool
    ///
    access(all)
    view fun borrowAirdropPool(_ addr: Address): &AirdropPool{AirdropPoolPoolPublic, FixesFungibleTokenInterface.IMinterHolder}? {
        // @deprecated in Cadence 1.0
        return getAccount(addr)
            .getCapability<&AirdropPool{AirdropPoolPoolPublic, FixesFungibleTokenInterface.IMinterHolder}>(self.getAirdropPoolPublicPath())
            .borrow()
    }

    /// Get the prefix for the storage paths
    ///
    access(all)
    view fun getPathPrefix(): String {
        return "FixesAirDrops_".concat(self.account.address.toString()).concat("_")
    }

    /// Get the storage path for the Locking Center
    ///
    access(all)
    view fun getAirdropPoolStoragePath(): StoragePath {
        let prefix = self.getPathPrefix()
        return StoragePath(identifier: prefix.concat("Pool"))!
    }

    /// Get the public path for the Liquidity Pool
    ///
    access(all)
    view fun getAirdropPoolPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("Pool"))!
    }
}
