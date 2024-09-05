/**
> Author: Fixes Lab <https://github.com/fixes-world/>

# FRC20VoteCommands

This contract is used to manage the frc20 vote commands.

*/
import "FlowToken"
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20StakingManager"
import "FRC20StakingVesting"
import "FGameLottery"
import "FGameLotteryRegistry"
import "FGameLotteryFactory"

access(all) contract FRC20VoteCommands {

    /// The Proposal command type.
    ///
    access(all) enum CommandType: UInt8 {
        access(all) case None;
        access(all) case SetBurnable;
        access(all) case BurnUnsupplied;
        access(all) case MoveTreasuryToLotteryJackpot;
        access(all) case MoveTreasuryToStakingReward;
    }

    /// The interface of FRC20 vote command struct.
    ///
    access(all) struct interface IVoteCommand {
        access(all)
        let inscriptionIds: [UInt64]

        // ----- Readonly Mehtods -----

        /// Get the command type.
        access(all)
        view fun getCommandType(): CommandType
        // It is readonly, but it is not a view function.
        access(all)
        fun verifyVoteCommands(): Bool

        /// Check if all inscriptions are extracted.
        ///
        access(all)
        view fun isAllInscriptionsExtracted(): Bool {
            let store = FRC20VoteCommands.borrowSystemInscriptionsStore()
            for id in self.inscriptionIds {
                if let insRef = store.borrowInscription(id) {
                    if !insRef.isExtracted() {
                        return false
                    }
                }
            }
            return true
        }

        // ----- Account level methods -----

        /// Refund the inscription cost for failed vote commands.
        ///
        access(account)
        fun refundFailedVoteCommands(receiver: Address): Bool {
            let recieverRef = Fixes.borrowFlowTokenReceiver(receiver)
            if recieverRef == nil {
                return false
            }
            let store = FRC20VoteCommands.borrowSystemInscriptionsStore()
            let insRefArr = self.borrowSystemInscriptionWritableRefs()

            let vault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
            for insRef in insRefArr {
                if !insRef.isExtracted() {
                    vault.deposit(from: <-insRef.extract())
                }
            }
            // deposit to the receiver
            recieverRef!.deposit(from: <- vault)
            return true
        }

        // Methods: Write
        access(account)
        fun safeRunVoteCommands(): Bool

        // ----- General Methods -----

        /// Borrow the system inscriptions references from store.
        ///
        access(contract)
        fun borrowSystemInscriptionWritableRefs(): [auth(Fixes.Extractable) &Fixes.Inscription] {
            let store = FRC20VoteCommands.borrowSystemInscriptionsStore()
            let ret: [auth(Fixes.Extractable) &Fixes.Inscription] = []
            for id in self.inscriptionIds {
                if let ref = store.borrowInscriptionWritableRefInAccount(id) {
                    ret.append(ref)
                }
            }
            return ret
        }
    }

    /**
     * Command: None
     */
    access(all) struct CommandNone: IVoteCommand {
        access(all)
        let inscriptionIds: [UInt64]

        init() {
            self.inscriptionIds = []
        }

        // ----- Methods: Read -----

        access(all)
        view fun getCommandType(): CommandType {
            return CommandType.None
        }

        access(all)
        fun verifyVoteCommands(): Bool {
            return true
        }

        // ---- Methods: Write ----

        access(account)
        fun safeRunVoteCommands(): Bool {
            return true
        }
    }

    /**
     * Command: SetBurnable
     */
    access(all) struct CommandSetBurnable: IVoteCommand {
        access(all)
        let inscriptionIds: [UInt64]

        init(_ insIds: [UInt64]) {
            self.inscriptionIds = insIds

            assert(
                self.verifyVoteCommands(),
                message: "Invalid vote commands"
            )
        }

        // ----- Methods: Read -----

        access(all)
        view fun getCommandType(): CommandType {
            return CommandType.SetBurnable
        }

        access(all)
        fun verifyVoteCommands(): Bool {
            var isValid = false
            isValid = self.inscriptionIds.length == 1
            if isValid {
                let store = FRC20VoteCommands.borrowSystemInscriptionsStore()
                if let ins = store.borrowInscription(self.inscriptionIds[0]) {
                    let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
                    isValid = FRC20VoteCommands.isValidSystemInscription(ins)
                        && meta["op"] == "burnable" && meta["tick"] != nil && meta["v"] != nil
                } else {
                    isValid = false
                }
            }
            return isValid
        }

        // ---- Methods: Write ----

        access(account)
        fun safeRunVoteCommands(): Bool {
            // Refs
            let frc20Indexer = FRC20Indexer.getIndexer()
            let insRefArr = self.borrowSystemInscriptionWritableRefs()

            if insRefArr.length != 1 {
                return false
            }
            frc20Indexer.setBurnable(ins: insRefArr[0])
            return true
        }
    }

    /**
     * Command: BurnUnsupplied
     */
    access(all) struct CommandBurnUnsupplied: IVoteCommand {
        access(all)
        let inscriptionIds: [UInt64]

        init(_ insIds: [UInt64]) {
            self.inscriptionIds = insIds

            assert(
                self.verifyVoteCommands(),
                message: "Invalid vote commands"
            )
        }

        // ----- Methods: Read -----

        access(all)
        view fun getCommandType(): CommandType {
            return CommandType.BurnUnsupplied
        }

        access(all)
        fun verifyVoteCommands(): Bool {
            // Refs
            let insRefArr = self.borrowSystemInscriptionWritableRefs()

            var isValid = insRefArr.length == 1
            if isValid {
                let ins = insRefArr[0]
                let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
                isValid = FRC20VoteCommands.isValidSystemInscription(ins)
                    && meta["op"] == "burnUnsup" && meta["tick"] != nil && meta["perc"] != nil
            }
            return isValid
        }

        // ---- Methods: Write ----

        access(account)
        fun safeRunVoteCommands(): Bool {
            // Refs
            let frc20Indexer = FRC20Indexer.getIndexer()
            let insRefArr = self.borrowSystemInscriptionWritableRefs()

            if insRefArr.length != 1 {
                return false
            }
            frc20Indexer.burnUnsupplied(ins: insRefArr[0])
            return true
        }
    }

    /**
     * Command: MoveTreasuryToLotteryJackpot
     */
    access(all) struct CommandMoveTreasuryToLotteryJackpot: IVoteCommand {
        access(all)
        let inscriptionIds: [UInt64]

        init(_ insIds: [UInt64]) {
            self.inscriptionIds = insIds

            assert(
                self.verifyVoteCommands(),
                message: "Invalid vote commands"
            )
        }

        // ----- Methods: Read -----

        access(all)
        view fun getCommandType(): CommandType {
            return CommandType.MoveTreasuryToLotteryJackpot
        }

        access(all)
        fun verifyVoteCommands(): Bool {
            var isValid = self.inscriptionIds.length == 1
            if isValid {
                let store = FRC20VoteCommands.borrowSystemInscriptionsStore()
                if let ins = store.borrowInscription(self.inscriptionIds[0]) {
                    let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
                    isValid = FRC20VoteCommands.isValidSystemInscription(ins)
                        && meta["op"] == "withdrawFromTreasury"
                        && meta["usage"] == "lottery"
                        && meta["tick"] != nil && meta["amt"] != nil
                } else {
                    isValid = false
                }
            }
            return isValid
        }

        // ---- Methods: Write ----

        access(account)
        fun safeRunVoteCommands(): Bool {
            // Refs
            let frc20Indexer = FRC20Indexer.getIndexer()
            let insRefArr = self.borrowSystemInscriptionWritableRefs()

            if insRefArr.length != 1 {
                return false
            }
            let flowLotteryName = FGameLotteryFactory.getFIXESMintingLotteryPoolName()
            let registery = FGameLotteryRegistry.borrowRegistry()
            if let poolAddr = registery.getLotteryPoolAddress(flowLotteryName) {
                if let poolRef = FGameLottery.borrowLotteryPool(poolAddr) {
                    let withdrawnChange <- frc20Indexer.withdrawFromTreasury(ins: insRefArr[0])
                    poolRef.donateToJackpot(payment: <- withdrawnChange)
                    return true
                }
            }
            log("Failed to find the lottery pool")
            return false
        }
    }

    /**
     * Command: MoveTreasuryToStakingReward
     */
    access(all) struct CommandMoveTreasuryToStakingReward: IVoteCommand {
        access(all)
        let inscriptionIds: [UInt64]

        init(_ insIds: [UInt64]) {
            self.inscriptionIds = insIds

            assert(
                self.verifyVoteCommands(),
                message: "Invalid vote commands"
            )
        }

        // ----- Methods: Read -----

        access(all)
        view fun getCommandType(): CommandType {
            return CommandType.MoveTreasuryToStakingReward
        }

        access(all)
        fun verifyVoteCommands(): Bool {
            var isValid = self.inscriptionIds.length == 1
            if isValid {
                let store = FRC20VoteCommands.borrowSystemInscriptionsStore()
                if let ins = store.borrowInscription(self.inscriptionIds[0]) {
                    let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
                    isValid = FRC20VoteCommands.isValidSystemInscription(ins)
                        && meta["op"] == "withdrawFromTreasury" && meta["usage"] == "staking"
                        && meta["tick"] != nil && meta["amt"] != nil
                        && meta["batch"] != nil && meta["interval"] != nil
                } else {
                    isValid = false
                }
            }
            return isValid
        }

        // ---- Methods: Write ----

        access(account)
        fun safeRunVoteCommands(): Bool {
            // Refs
            let frc20Indexer = FRC20Indexer.getIndexer()
            let insRefArr = self.borrowSystemInscriptionWritableRefs()

            if insRefArr.length != 1 {
                return false
            }
            let ins = insRefArr[0]
            let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())

            // singleton resources
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            let platformStakeTick = FRC20FTShared.getPlatformStakingTickerName()
            let vestingBatch = UInt32.fromString(meta["batch"]!)
            let vestingInterval = UFix64.fromString(meta["interval"]!)
            if vestingBatch == nil || vestingInterval == nil {
                log("Invalid vesting batch or interval")
                return false
            }
            if let stakingAddress = acctsPool.getFRC20StakingAddress(tick: platformStakeTick) {
                if let vestingVault = FRC20StakingVesting.borrowVaultRef(stakingAddress) {
                    let withdrawnChange <- frc20Indexer.withdrawFromTreasury(ins: insRefArr[0])
                    FRC20StakingManager.donateToVestingFromChange(
                        changeToDonate: <- withdrawnChange,
                        tick: platformStakeTick,
                        vestingBatchAmount: vestingBatch!,
                        vestingInterval: vestingInterval!
                    )
                    return true
                }
            }
            log("Failed to find valid staking pool")
            return false
        }
    }

    /// Check if the given inscription is a valid system inscription.
    ///
    access(contract)
    view fun isValidSystemInscription(_ ins: &Fixes.Inscription): Bool {
        let frc20Indexer = FRC20Indexer.getIndexer()
        return ins.owner?.address == self.account.address
            && ins.isExtractable()
            && frc20Indexer.isValidFRC20Inscription(ins: ins)
    }

    /// Borrow the system inscriptions store.
    ///
    access(all)
    view fun borrowSystemInscriptionsStore(): &Fixes.InscriptionsStore {
        let storePubPath = Fixes.getFixesStorePublicPath()
        return self.account
            .capabilities.get<&Fixes.InscriptionsStore>(storePubPath)
            .borrow() ?? panic("Fixes.InscriptionsStore is not found")
    }

    /// Build the inscription strings by the given command type and meta.
    ///
    access(all)
    view fun buildInscriptionStringsByCommand(_ type: CommandType, _ meta: {String: String}): [String] {
        switch type {
        case CommandType.None:
            return []
        case CommandType.SetBurnable:
            return [
                FixesInscriptionFactory.buildVoteCommandSetBurnable(
                    tick: meta["tick"] ?? panic("Missing tick in params"),
                    burnable: meta["v"] == "1"
                )
            ]
        case CommandType.BurnUnsupplied:
            return [
                FixesInscriptionFactory.buildVoteCommandBurnUnsupplied(
                    tick: meta["tick"] ?? panic("Missing tick in params"),
                    percent: UFix64.fromString(meta["perc"] ?? panic("Missing perc in params")) ?? panic("Invalid perc")
                )
            ]
        case CommandType.MoveTreasuryToLotteryJackpot:
            return [
                FixesInscriptionFactory.buildVoteCommandMoveTreasuryToLotteryJackpot(
                    tick: meta["tick"] ?? panic("Missing tick in params"),
                    amount: UFix64.fromString(meta["amt"] ?? panic("Missing amt in params")) ?? panic("Invalid amt")
                )
            ]
        case CommandType.MoveTreasuryToStakingReward:
            return [
                FixesInscriptionFactory.buildVoteCommandMoveTreasuryToStaking(
                    tick: meta["tick"] ?? panic("Missing tick in params"),
                    amount: UFix64.fromString(meta["amt"] ?? panic("Missing amt in params")) ?? panic("Invalid amt"),
                    vestingBatchAmount: UInt32.fromString(meta["batch"] ?? panic("Missing batch in params")) ?? panic("Invalid batch"),
                    vestingInterval: UFix64.fromString(meta["interval"] ?? panic("Missing interval in params")) ?? panic("Invalid interval")
                )
            ]
        }
        panic("Invalid command type")
    }

    /// Create a vote command by the given type and inscriptions.
    ///
    access(all)
    fun createByCommandType(_ type: CommandType, _ inscriptions: [UInt64]): {IVoteCommand} {
        let store = self.borrowSystemInscriptionsStore()
        // Ensure the inscriptions are valid
        for ins in inscriptions {
            let insRef = store.borrowInscription(ins)
            if insRef == nil {
                panic("Invalid inscription")
            }
        }

        switch type {
        case CommandType.None:
            return CommandNone()
        case CommandType.SetBurnable:
            return CommandSetBurnable(inscriptions)
        case CommandType.BurnUnsupplied:
            return CommandBurnUnsupplied(inscriptions)
        case CommandType.MoveTreasuryToLotteryJackpot:
            return CommandMoveTreasuryToLotteryJackpot(inscriptions)
        case CommandType.MoveTreasuryToStakingReward:
            return CommandMoveTreasuryToStakingReward(inscriptions)
        }
        panic("Invalid command type")
    }
}
