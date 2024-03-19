/**
> Author: FIXeS World <https://fixes.world/>

# FRC20Votes

This contract is used to manage the FRC20 votes.

*/
import "FlowToken"
import "Fixes"
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20SemiNFT"
import "FRC20Staking"

access(all) contract FRC20VoteCommands {

    /// The Proposal command type.
    ///
    access(all) enum CommandType: UInt8 {
        access(all) case None;
        access(all) case SetBurnable;
        access(all) case BurnUnsupplied;
        access(all) case MoveUnsuppliedToLotteryJackpot;
        access(all) case MoveTreasuryToLotteryJackpot;
    }

    access(account)
    fun verifyVoteCommands(_ commandType: CommandType, _ insRefArr: [&Fixes.Inscription{Fixes.InscriptionPublic}]): Bool {
        return false
    }

    access(account)
    fun safeRunVoteCommands(_ commandType: CommandType, _ insRefArr: [&Fixes.Inscription]): Bool {
        return false
    }

    access(account)
    fun refundFailedVoteCommands(receiver: Address, _ insRefArr: [&Fixes.Inscription]): Bool {
        return false
    }
}
