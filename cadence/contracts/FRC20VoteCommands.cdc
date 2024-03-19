/**
> Author: FIXeS World <https://fixes.world/>

# FRC20Votes

This contract is used to manage the FRC20 votes.

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

    access(account) view
    fun verifyVoteCommands(_ commandType: CommandType, _ insRefArr: [&Fixes.Inscription{Fixes.InscriptionPublic}]): Bool {
        // Singleton Resource
        let frc20Indexer = FRC20Indexer.getIndexer()

        var isValid = false
        switch commandType {
        case CommandType.SetBurnable:
            isValid = insRefArr.length == 1
            if isValid {
                let ins = insRefArr[0]
                let meta = frc20Indexer.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
                isValid = self._isValidSystemInscription(ins)
                    && meta["op"] == "burnable" && meta["tick"] != nil && meta["v"] != nil
            }
            break
        case CommandType.BurnUnsupplied:
            isValid = insRefArr.length == 1
            if isValid {
                let ins = insRefArr[0]
                let meta = frc20Indexer.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
                isValid = self._isValidSystemInscription(ins)
                    && meta["op"] == "burnUnsup" && meta["tick"] != nil && meta["perc"] != nil
            }
            break
        case CommandType.MoveTreasuryToLotteryJackpot:
            isValid = insRefArr.length == 1
            if isValid {
                let ins = insRefArr[0]
                let meta = frc20Indexer.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
                isValid = self._isValidSystemInscription(ins)
                    && meta["op"] == "withdrawFromTreasury" && meta["usage"] == "lottery" && meta["tick"] != nil && meta["amt"] != nil
            }
            break
        case CommandType.MoveTreasuryToStakingReward:
            isValid = insRefArr.length == 1
            if isValid {
                let ins = insRefArr[0]
                let meta = frc20Indexer.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
                isValid = self._isValidSystemInscription(ins)
                    && meta["op"] == "withdrawFromTreasury" && meta["usage"] == "staking"
                    && meta["tick"] != nil && meta["amt"] != nil
                    && meta["batch"] != nil && meta["interval"] != nil
            }
            break
        }
        return isValid
    }

    access(account)
    fun safeRunVoteCommands(_ commandType: CommandType, _ insRefArr: [&Fixes.Inscription]): Bool {
        let isValid = self.verifyVoteCommands(commandType, insRefArr)
        if !isValid {
            return false
        }

        // Singleton Resource
        let frc20Indexer = FRC20Indexer.getIndexer()

        switch commandType {
        case CommandType.SetBurnable:
            if insRefArr.length != 1 {
                return false
            }
            frc20Indexer.setBurnable(ins: insRefArr[0])
            return true
        case CommandType.BurnUnsupplied:
            if insRefArr.length != 1 {
                return false
            }
            frc20Indexer.burnUnsupplied(ins: insRefArr[0])
            return true
        case CommandType.MoveTreasuryToLotteryJackpot:
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
        case CommandType.MoveTreasuryToStakingReward:
            if insRefArr.length != 1 {
                return false
            }
            let ins = insRefArr[0]
            let meta = frc20Indexer.parseMetadata(&ins.getData() as &Fixes.InscriptionData)

            // singleton resources
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            let platformStakeTick = FRC20StakingManager.getPlatformStakingTickerName()
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
        log("Unknown command type")
        return false
    }

    /// Refund the inscription cost for failed vote commands.
    ///
    access(account)
    fun refundFailedVoteCommands(receiver: Address, _ insRefArr: [&Fixes.Inscription]): Bool {
        let recieverRef = FRC20Indexer.borrowFlowTokenReceiver(receiver)
        if recieverRef == nil {
            return false
        }

        let vault <- FlowToken.createEmptyVault()
        for insRef in insRefArr {
            if !insRef.isExtracted() {
                vault.deposit(from: <-insRef.extract())
            }
        }
        // deposit to the receiver
        recieverRef!.deposit(from: <- vault)
        return true
    }

    /// Check if the given inscription is a valid system inscription.
    ///
    access(contract)
    fun _isValidSystemInscription(_ ins: &Fixes.Inscription{Fixes.InscriptionPublic}): Bool {
        let frc20Indexer = FRC20Indexer.getIndexer()
        return ins.owner?.address == self.account.address
            && ins.isExtractable()
            && frc20Indexer.isValidFRC20Inscription(ins: ins)
    }
}
