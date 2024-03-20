import "FRC20Votes"

access(all)
fun main(): [ProposalInfo] {
    let votesMgr = FRC20Votes.borrowVotesManager()
    let ids = votesMgr.getActiveProposalIds()
    let ret: [ProposalInfo] = []
    for id in ids {
        if let proposal = votesMgr.borrowProposal(id) {
            ret.append(ProposalInfo(
                id: proposal.uuid,
                proposer: proposal.getProposer(),
                details: proposal.getDetails(),
                status: proposal.getStatus(),
                isEditable: proposal.isEditable(),
                voterAmount: proposal.getVotersAmount(),
                votedPoints: proposal.getTotalVotedPoints(),
                winningChoice: proposal.getWinningChoice()
            ))
        }
    }
    return ret
}

/// ProposalInfo is a struct that contains the information of a proposal.
///
access(all) struct ProposalInfo {
    // Basic information of a proposal.
    access(all)
    let id: UInt64
    access(all)
    let proposer: Address
    access(all)
    let details: FRC20Votes.ProposalDetails
    access(all)
    let status: FRC20Votes.ProposalStatus
    access(all)
    let isEditable: Bool
    access(all)
    let voterAmount: Int
    access(all)
    let votedPoints: UFix64
    access(all)
    let winningChoice: Int?

    init(
        id: UInt64,
        proposer: Address,
        details: FRC20Votes.ProposalDetails,
        status: FRC20Votes.ProposalStatus,
        isEditable: Bool,
        voterAmount: Int,
        votedPoints: UFix64,
        winningChoice: Int?
    ) {
        self.id = id
        self.proposer = proposer
        self.details = details
        self.status = status
        self.isEditable = isEditable
        self.voterAmount = voterAmount
        self.votedPoints = votedPoints
        self.winningChoice = winningChoice
    }
}
