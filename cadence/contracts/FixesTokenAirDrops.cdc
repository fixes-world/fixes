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
access(all) contract FixesTokenAirDrops {

    // ------ Events -------

    // emitted when a new Drops Pool is created
    access(all) event AirdropPoolCreated(
        tokenType: Type,
        tokenSymbol: String,
        minterGrantedAmount: UFix64,
        createdBy: Address
    )

    // emitted when the claimable amount is set
    access(all) event AirdropPoolSetClaimable(
        tokenType: Type,
        tokenSymbol: String,
        claimables: {Address: UFix64},
        currentGrantedAmount: UFix64,
        by: Address
    )

    // emitted when the claimable amount is claimed
    access(all) event AirdropPoolClaimed(
        tokenType: Type,
        tokenSymbol: String,
        claimer: Address,
        claimedAmount: UFix64,
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
            pre {
                minter.getTotalAllowedMintableAmount() > 0.0: "The mint amount must be greater than 0"
            }
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
            pre {
                self.getTotalClaimableAmount() < self.getTotalAllowedMintableAmount(): "The total claimable amount exceeds the mintable amount"
            }
            let callerAddr = ins.owner?.address ?? panic("The owner is missing")
            assert(
                self.isAuthorizedUser(callerAddr),
                message: "The caller is not an authorized user"
            )

            // extract the inscription
            FixesTradablePool.verifyAndExecuteInscription(
                ins,
                symbol: self.minter.getSymbol(),
                usage: "set-claimables"
            )

            // Total claimable amount
            let totalClaimableAmount = self.minter.getCurrentMintableAmount()
            let oldGrantedClaimableAmount = self.grantedClaimableAmount
            var newGrantedClaimableAmount = oldGrantedClaimableAmount

            // set the claimable amount
            for addr in claimables.keys {
                if let amount = claimables[addr] {
                    self.claimableRecords[addr] = amount + (self.claimableRecords[addr] ?? 0.0)
                    newGrantedClaimableAmount = newGrantedClaimableAmount + amount
                }
            }
            assert(
                newGrantedClaimableAmount <= totalClaimableAmount,
                message: "The total claimable amount exceeds the mintable amount"
            )
            self.grantedClaimableAmount = newGrantedClaimableAmount
            log("The granted claimable amount is updated from ".concat(oldGrantedClaimableAmount.toString())
                .concat(" to ").concat(newGrantedClaimableAmount.toString()))

            // emit the event
            emit AirdropPoolSetClaimable(
                tokenType: self.minter.getTokenType(),
                tokenSymbol: self.minter.getSymbol(),
                claimables: claimables,
                currentGrantedAmount: newGrantedClaimableAmount,
                by: callerAddr
            )
        }

        /// Claim drops token
        access(all)
        fun claimDrops(
            _ ins: &Fixes.Inscription,
            recipient: &{FungibleToken.Receiver},
        ) {
            let callerAddr = ins.owner?.address ?? panic("The owner is missing")
            assert(
                callerAddr == recipient.owner?.address,
                message: "The caller is not the recipient"
            )

            let claimableAmount = self.getClaimableTokenAmount(callerAddr)

            assert(
                claimableAmount > 0.0,
                message: "The caller has no claimable amount"
            )

            let supportTypes = recipient.getSupportedVaultTypes()
            assert(
                supportTypes[self.minter.getTokenType()] == true,
                message: "The recipient does not support the token"
            )

            // initialize the vault by inscription, op=exec
            let vaultData = self.minter.getVaultData()
            let initializedVault <- self.minter.initializeVaultByInscription(
                vault: <- vaultData.createEmptyVault(),
                ins: ins
            )
            // mint the token
            initializedVault.deposit(from: <- self.minter.mintTokens(amount: claimableAmount))
            // update the claimable amount
            self.claimableRecords[callerAddr] = 0.0

            // transfer the token
            recipient.deposit(from: <- initializedVault)

            // emit the event
            emit AirdropPoolClaimed(
                tokenType: self.minter.getTokenType(),
                tokenSymbol: self.minter.getSymbol(),
                claimer: callerAddr,
                claimedAmount: claimableAmount
            )
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
        view fun borrowMinter(): &{FixesFungibleTokenInterface.IMinter} {
            return &self.minter as &{FixesFungibleTokenInterface.IMinter}
        }

        // ----- Internal Methods -----

        /// Check if the caller is an authorized user
        ///
        access(self)
        view fun isAuthorizedUser(_ callerAddr: Address): Bool {
            // singleton resources
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            // The caller should be authorized user for the token
            let key = self.minter.getAccountsPoolKey() ?? panic("The accounts pool key is missing")
            // borrow the contract
            let contractRef = acctsPool.borrowFTContract(key) ?? panic("The contract is missing")
            let globalPublicRef = contractRef.borrowGlobalPublic()
            return globalPublicRef.isAuthorizedUser(callerAddr)
        }
    }


    /// ------ Public Methods ------

    /// Create a new Airdrop Pool
    ///
    access(account)
    fun createDropsPool(
        _ ins: &Fixes.Inscription,
        _ minter: @{FixesFungibleTokenInterface.IMinter},
    ): @AirdropPool {
        pre {
            ins.isExtractable(): "The inscription is not extractable"
        }
        post {
            ins.isExtracted(): "The inscription is not extracted"
        }

        // verify the inscription and get the meta data
        let meta =  FixesTradablePool.verifyAndExecuteInscription(
            ins,
            symbol: minter.getSymbol(),
            usage: "*"
        )

        let tokenType = minter.getTokenType()
        let tokenSymbol = minter.getSymbol()
        let grantedAmount = minter.getCurrentMintableAmount()

        let pool <- create AirdropPool(<- minter)

        // emit the event
        emit AirdropPoolCreated(
            tokenType: tokenType,
            tokenSymbol: tokenSymbol,
            minterGrantedAmount: grantedAmount,
            createdBy: ins.owner?.address ?? panic("The inscription owner is missing")
        )

        return <- pool
    }

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
