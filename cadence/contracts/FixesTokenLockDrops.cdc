/**

> Author: FIXeS World <https://fixes.world/>

# FixesTokenLockDrops

This is a lockdrop service contract for the FIXeS token.
It allows users to lock their frc20/fungible tokens for a certain period of time and earn fixes token.

*/
import "FungibleToken"
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FRC20AccountsPool"

/// The contract definition
///
access(all) contract FixesTokenLockDrops {

    // ------ Events -------


    /// -------- Resources and Interfaces --------

    /// Public resource interface for the Locking Center
    ///
    access(all) resource interface CeneterPublic {

    }

    /// Locking Center Resource
    ///
    access(all) resource LockingCenter: CeneterPublic {

    }

    /// Public resource interface for the Drops Pool
    ///
    access(all) resource interface DropsPoolPublic {

    }

    /// Drops Pool Resource
    ///
    access(all) resource DropsPool: DropsPoolPublic {

    }


    /// ------ Public Methods ------

    /// Create a new Drops Pool
    ///
    access(all)
    fun createDropsPool(
        ins: &Fixes.Inscription,
        _ minter: @{FixesFungibleTokenInterface.IMinter},
    ): @DropsPool {
        pre {
            ins.isExtractable(): "The inscription is not extractable"
        }
        post {
            ins.isExtracted(): "The inscription is not extracted"
        }
        // singletons
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        let meta = FixesInscriptionFactory.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
        let tick = meta["tick"] ?? panic("The ticker name is not found")
        assert(
            acctsPool.getFTContractAddress(tick) != nil,
            message: "The FungibleToken contract is not found"
        )
        assert(
            tick == "$".concat(minter.getSymbol()),
            message: "The minter capability address is not the same as the FungibleToken contract"
        )

        // execute the inscription
        acctsPool.executeInscription(type: FRC20AccountsPool.ChildAccountType.FungibleToken, ins)

        let pool <- create DropsPool()

        let tokenType = minter.getTokenType()
        let tokenSymbol = minter.getSymbol()

        // emit the created event
        // emit DropsPoolCreated(
        //     tokenType: tokenType,
        //     createdBy: ins.owner?.address ?? panic("The inscription owner is missing")
        // )

        return <- pool
    }

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

    init() {
        // Create the Locking Center
    }
}
