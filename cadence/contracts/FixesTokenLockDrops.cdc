/**

> Author: FIXeS World <https://fixes.world/>

# FixesTokenLockDrops

This is a lockdrop service contract for the FIXeS token.
It allows users to lock their frc20/fungible tokens for a certain period of time and earn fixes token.

*/
import "FungibleToken"
import "Fixes"

/// The contract definition
///
access(all) contract FixesTokenLockDrops {

    // ------ Events -------


    /// -------- Resources and Interfaces --------


    /// ------ Public Methods ------

    /// Get the prefix for the storage paths
    ///
    access(all)
    view fun getPathPrefix(): String {
        return "FixesLockDrops_".concat(self.account.address.toString()).concat("_")
    }

    /// Get the storage path for the Locking Center
    ///
    access(all)
    view fun getLockingCenterStoragePath(): StoragePath {
        let prefix = self.getPathPrefix()
        return StoragePath(identifier: prefix.concat("LockingCenter"))!
    }

    /// Get the public path for the Liquidity Pool
    ///
    access(all)
    view fun getLockingCenterPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("LockingCenter"))!
    }

    /// Get the storage path for the Locking Center
    ///
    access(all)
    view fun getDropsPoolStoragePath(): StoragePath {
        let prefix = self.getPathPrefix()
        return StoragePath(identifier: prefix.concat("DropsPool"))!
    }

    /// Get the public path for the Liquidity Pool
    ///
    access(all)
    view fun getDropsPoolPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("DropsPool"))!
    }
}
