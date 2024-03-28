import "FRC20Votes"

access(all)
fun main(
    proposalId: UInt64,
    addr: Address?,
): ProposalDetailedInfo? {
    let votesMgr = FRC20Votes.borrowVotesManager()
    let ids = votesMgr.getActiveProposalIds()
    if let proposal = votesMgr.borrowProposal(proposalId) {
        let voter = addr != nil ? FRC20Votes.borrowVoterPublic(addr!) : nil
        return ProposalDetailedInfo(
            id: proposal.uuid,
            proposer: proposal.getProposer(),
            details: proposal.getDetails(),
            status: proposal.getStatus(),
            isEditable: proposal.isEditable(),
            voterAmount: proposal.getVotersAmount(),
            votedPoints: proposal.getTotalVotedPoints(),
            votingChoices: proposal.getVotingChoices(),
            winningChoice: proposal.getWinningChoice(),
            // Detailed information of a proposal.
            logs: proposal.getLogs(),
            voters: proposal.getVoters(),
            isVoteCommandsExecutable: proposal.isVoteCommandsExecutable(),
            // Voter Status
            currentHasVoted: voter?.hasVoted(proposalId),
            currentVotedPoints: voter?.getVotedPoints(proposalId) ?? nil,
            currentVotedChoice: voter?.getVotedChoice(proposalId) ?? nil,
            currentVotingPower: voter?.getVotingPower() ?? nil,
        )
    }
    return nil
}

/// ProposalInfo is a struct that contains the information of a proposal.
///
access(all) struct ProposalDetailedInfo {
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
    let thresholdPoints: UFix64
    access(all)
    let slotsTypes: [String]
    access(all)
    let votingChoices: {Int: UFix64}
    access(all)
    let winningChoice: Int?
    // Detailed information of a proposal.
    access(all)
    let logs: [FRC20Votes.StatusLog]
    access(all)
    let voters: [Address]
    access(all)
    let isVoteCommandsExecutable: Bool
    // Voter Status
    access(all)
    let currentHasVoted: Bool?
    access(all)
    let currentVotedPoints: UFix64?
    access(all)
    let currentVotedChoice: Int?
    access(all)
    let currentVotingPower: UFix64?

    init(
        id: UInt64,
        proposer: Address,
        details: FRC20Votes.ProposalDetails,
        status: FRC20Votes.ProposalStatus,
        isEditable: Bool,
        voterAmount: Int,
        votedPoints: UFix64,
        votingChoices: {Int: UFix64},
        winningChoice: Int?,
        logs: [FRC20Votes.StatusLog],
        voters: [Address],
        isVoteCommandsExecutable: Bool,
        currentHasVoted: Bool?,
        currentVotedPoints: UFix64?,
        currentVotedChoice: Int?,
        currentVotingPower: UFix64?
    ) {
        self.id = id
        self.proposer = proposer
        self.details = details
        self.status = status
        self.isEditable = isEditable
        self.voterAmount = voterAmount
        self.votedPoints = votedPoints
        self.winningChoice = winningChoice
        self.votingChoices = votingChoices
        let slotsTypes: [String] = []
        for s in details.slots {
            slotsTypes.append(s.command.getType().identifier)
        }
        self.slotsTypes = slotsTypes
        let totalStakedAmount = FRC20Votes.getTotalStakedAmount()
        self.thresholdPoints = details.executableThreshold * totalStakedAmount

        self.logs = logs
        self.voters = voters
        self.isVoteCommandsExecutable = isVoteCommandsExecutable
        self.currentHasVoted = currentHasVoted
        self.currentVotedPoints = currentVotedPoints
        self.currentVotedChoice = currentVotedChoice
        self.currentVotingPower = currentVotingPower
    }
}
