import "FRC20FTShared"
import "FRC20Votes"
import "FRC20Staking"
import "FRC20StakingManager"

access(all)
fun main(
    addr: Address
): VotingStatus {
    let votesMgr = FRC20Votes.borrowVotesManager()
    var votingPower = 0.0
    if let ref = FRC20Votes.borrowVoterPublic(addr) {
        votingPower = ref.getVotingPower()
    } else if let delegatorRef = FRC20Staking.borrowDelegator(addr) {
        let stakeTick = FRC20FTShared.getPlatformStakingTickerName()
        votingPower = delegatorRef.getStakedBalance(tick: stakeTick)
    }
    return VotingStatus(
        votingPower,
        votesMgr.isValidProposer(addr)
    )
}

access(all) struct VotingStatus {
    access(all) let votingPower: UFix64
    access(all) let isValidProposer: Bool

    init(
        _ votingPower: UFix64,
        _ isValidProposer: Bool,
    ) {
        self.votingPower = votingPower
        self.isValidProposer = isValidProposer
    }
}
