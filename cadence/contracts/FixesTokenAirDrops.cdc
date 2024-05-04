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

    }

    /// The Airdrop Pool resource
    ///
    access(all) resource AirdropPool: AirdropPoolPoolPublic, FixesFungibleTokenInterface.IMinterHolder {
        // The minter of the token
        access(self)
        let minter: @{FixesFungibleTokenInterface.IMinter}

        init(
            _ minter: @{FixesFungibleTokenInterface.IMinter},
        ) {
            self.minter <- minter
        }

        destroy() {
            destroy self.minter
        }

        // ------ Implment AirdropPoolPoolPublic ------



        // ------ Implment FixesFungibleTokenInterface.IMinterHolder ------

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
