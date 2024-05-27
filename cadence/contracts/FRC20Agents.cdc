/**
> Author: FIXeS World <https://fixes.world/>

# FRC20 Indexer Agent

This the agent controller for FRC20Indexer.

*/
// Fixes imports
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20FTShared"
import "FRC20Indexer"

/// This contract provides some agents.
/// IndexerController - The owner of this resource can invoke some methods with access(account) in the FRC20Indexer.
///
access(all) contract FRC20Agents {

    /// The private resource interface for the IndexerController.
    ///
    access(all) resource interface IndexerControllerInterface {
        /// Returns the accept ticks.
        access(all)
        view fun getAcceptTicks(): [String]

        /// Check if the tick is accepted.
        access(all)
        view fun isTickAccepted(tick: String): Bool {
            return self.getAcceptTicks().contains(tick)
        }

        /// Check if the inscription is accepted.
        access(all)
        fun isInscriptionAccepted(ins: &Fixes.Inscription): Bool {
            let meta = FixesInscriptionFactory.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
            if let tick = meta["tick"]?.toLower() {
                return self.isTickAccepted(tick: tick)
            }
            return false
        }

        // ------ FRC20Indexer methods -------

        /// Ensure the balance of an address exists
        access(all)
        fun ensureBalanceExists(tick: String, addr: Address) {
            pre {
                self.isTickAccepted(tick: tick): "The tick is not accepted"
            }
        }

        /// Withdraw amount of a FRC20 token by a FRC20 inscription
        access(all)
        fun withdrawChange(ins: &Fixes.Inscription): @FRC20FTShared.Change

        /// Deposit a FRC20 token change to indexer
        access(all)
        fun depositChange(ins: &Fixes.Inscription, change: @FRC20FTShared.Change)
    }

    /// This resource provides some FRC20Indexer access(account) methods that can be invoked by the owner of this resource.
    /// The interface is not exposed to the public.
    ///
    access(all) resource IndexerController: IndexerControllerInterface {
        access(self)
        let acceptTicks: [String]

        init(ticks: [String]) {
            self.acceptTicks = ticks
        }

        /// ----- Public methods for the resource -------

        access(all)
        view fun getAcceptTicks(): [String] {
            return self.acceptTicks
        }

        /// ------- Restricted methods for the resource -------

        access(all)
        fun addAcceptTick(tick: String) {
            self.acceptTicks.append(tick)
        }

        access(all)
        fun createEmptyChange(tick: String, from: Address): @FRC20FTShared.Change {
            pre {
                self.isTickAccepted(tick: tick): "The tick is not accepted"
            }
            return <- FRC20FTShared.createEmptyChange(tick: tick, from: from)
        }

        /// ------- Public methods for some access(account) methods of FRC20Indexer -------

        access(all)
        fun ensureBalanceExists(tick: String, addr: Address) {
            let indexer = FRC20Indexer.getIndexer()
            return indexer.ensureBalanceExists(tick: tick, addr: addr)
        }

        access(all)
        fun withdrawChange(ins: &Fixes.Inscription): @FRC20FTShared.Change {
            assert(
                self.isInscriptionAccepted(ins: ins),
                message: "The inscription is not accepted"
            )
            let indexer = FRC20Indexer.getIndexer()
            return <- indexer.withdrawChange(ins: ins)
        }

        access(all)
        fun depositChange(ins: &Fixes.Inscription, change: @FRC20FTShared.Change) {
            assert(
                self.isInscriptionAccepted(ins: ins),
                message: "The inscription is not accepted"
            )
            let indexer = FRC20Indexer.getIndexer()
            indexer.depositChange(ins: ins, change: <- change)
        }
    }

    /// Creates a new instance of the IndexerController.
    ///
    access(account)
    fun createIndexerController(_ ticks: [String]): @IndexerController {
        return <- create IndexerController(ticks: ticks)
    }

    /// Returns the storage path of the IndexerController.
    ///
    access(all)
    view fun getIndexerControllerStoragePath(): StoragePath {
        let identifier = self.getContractPrefix().concat("IndexerController")
        return StoragePath(identifier: identifier)!
    }

    /// Returns the contract prefix.
    ///
    access(all)
    view fun getContractPrefix(): String {
        return "FRC20Agents_".concat(self.account.address.toString()).concat("_")
    }
}
