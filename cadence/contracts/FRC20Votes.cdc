import "Fixes"
import "FRC20Indexer"

access(all) contract FRC20Votes {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /// Event emitted when a proposal is created
    access(all) event ProposalCreated(
        tick: String,
        proposalId: UInt64,
        proposer: Address,
        message: String,
        command: UInt8,
        inscriptions: [UInt64],
    )
    /// Event emitted when a proposal is voted
    access(all) event ProposalVoted(
        tick: String,
        proposalId: UInt64,
        voter: Address,
        choice: UInt8
    )
    /// Event emitted when a proposal is executed
    access(all) event ProposalExecuted(
        tick: String,
        proposalId: UInt64,
        choice: UInt8,
        executedAt: UFix64,
        success: Bool
    )

    /* --- Variable, Enums and Structs --- */

    access(all)
    let VoterStoragePath: StoragePath
    access(all)
    let VoterPublicPath: PublicPath
    access(all)
    let FRC20VotesManagerStoragePath: StoragePath
    access(all)
    let FRC20VotesManagerPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    access(all) resource interface VoterPublic {
        access(all)
        fun hasVoted(tick: String, proposalId: UInt64): Bool
        access(all)
        fun getVotedProposals(tick: String): [UInt64]
    }

    /// The resource of the FixesVotes voter identifier.
    ///
    access(all) resource VoterIdentity: VoterPublic {
        access(self)
        let voted: {String: {UInt64: Bool}}

        init() {
            self.voted = {}
        }

        /** ----- Read ----- */

        access(all)
        fun hasVoted(tick: String, proposalId: UInt64): Bool {
            if let tickVoted = self.voted[tick] {
                return tickVoted[proposalId] ?? false
            } else {
                return false
            }
        }

        access(all)
        fun getVotedProposals(tick: String): [UInt64] {
            if let tickVoted = self.voted[tick] {
                return tickVoted.keys
            } else {
                return []
            }
        }

        /** ----- Write ----- */

        access(contract)
        fun onVote(tick: String, proposalId: UInt64) {
            post {
                self.voted[tick]![proposalId] == true
            }
            if let tickVoted = &self.voted[tick] as &{UInt64: Bool}? {
                tickVoted[proposalId] = true
            } else {
                let tickVoted: {UInt64: Bool} = {}
                tickVoted[proposalId] = true
                self.voted[tick] = tickVoted
            }
        }
    }

    /// The Proposal status.
    ///
    access(all) enum ProposalStatus: UInt8 {
        access(all) case Drafting;
        access(all) case Voting;
        access(all) case Executed;
        access(all) case Cancelled;
    }

    /// The Proposal command type.
    ///
    access(all) enum CommandType: UInt8 {
        access(all) case MarketplaceFee;
        access(all) case BurnUnsupplied;
        access(all) case SetBurnable;
    }

    /// The struct of the FixesVotes proposal.
    ///
    access(all) struct Proposal {
        access(all)
        let proposer: Address
        access(all)
        let tick: String
        access(all)
        let votingWeight: {String: UFix64}
        access(all)
        let message: String
        access(all)
        let commandType: CommandType
        access(all)
        let slots: UInt8
        access(all)
        var status: ProposalStatus
        access(all)
        var endAt: UFix64?
        access(all)
        var votersAmt: UInt64
        access(all)
        var votes: {UInt8: UFix64}

        init(
            proposer: Address,
            tick: String,
            weights: {String: UFix64},
            message: String,
            commandType: CommandType,
            slots: UInt8,
        ) {
            pre {
                slots > 0: "Slots must be greater than 0"
                weights.length > 0: "Weights must be greater than 0"
            }
            self.proposer = proposer
            self.tick = tick
            self.votingWeight = weights
            self.message = message
            self.commandType = commandType
            self.slots = slots
            self.status = ProposalStatus.Drafting
            self.endAt = nil
            self.votersAmt = 0
            // init votes
            self.votes = {}
            var i = 0 as UInt8
            while i < slots {
                self.votes[i] = 0.0
                i = i + 1
            }
        }

        /** ----- Read ----- */

        /// The Proposal is ended if the endAt is not nil.
        ///
        access(all) view
        fun isEnded(): Bool {
            return self.endAt != nil
        }

        /// Get the winning choice.
        ///
        access(all) view
        fun getWinningChoice(): UInt8? {
            if !self.isEnded() {
                return nil
            }
            // get the winning choice
            var winningChoice = 0 as UInt8
            var winningVotes = 0.0
            for k in self.votes.keys {
                if let points = self.votes[k] {
                    if points > winningVotes {
                        winningChoice = k
                        winningVotes = points
                    }
                }
            }
            return winningChoice
        }

        /** ----- Write ----- */

        /// Write: Update the Proposal status.
        ///
        access(contract)
        fun updateStatus(status: ProposalStatus) {
            pre {
                status.rawValue > self.status.rawValue: "Cannot update status to a lower value"
            }
            self.status = status
            // update endAt
            if status == ProposalStatus.Executed || status == ProposalStatus.Cancelled {
                self.endAt = getCurrentBlock().timestamp
            }
        }

        access(contract)
        fun vote(choice: UInt8, tick: String, points: UFix64) {
            pre {
                self.status == ProposalStatus.Voting: "Proposal is not in voting status"
                choice < self.slots: "Choice is out of range"
                points > 0.0: "Points must be greater than 0"
                self.votingWeight[tick] != nil: "Voting weight is not found"
            }
            let weight = self.votingWeight[tick]!
            self.votes[choice] = self.votes[choice]! + weight * points
            self.votersAmt = self.votersAmt + 1
        }
    }

    /// The public interface of the FixesVotes manager.
    ///
    access(all) resource interface VotesManagerPublic {

    }

    /// The resource of the FixesVotes manager.
    ///
    access(all) resource VotesManager: VotesManagerPublic {
        access(self)
        let proposals: {String: [UInt64]}
        access(self)
        let proposalDetails: {UInt64: Proposal}
        access(self)
        let pendingInscriptions: @{UInt64: [Fixes.Inscription]}
        access(self)
        let appliedInscriptions: @{UInt64: [Fixes.Inscription]}

        init() {
            self.proposals = {}
            self.proposalDetails = {}
            self.pendingInscriptions <- {}
            self.appliedInscriptions <- {}
        }

        destroy() {
            destroy self.pendingInscriptions
            destroy self.appliedInscriptions
        }

        /** ----- Read ----- */

        access(all) view
        fun getProposalIds(tick: String): [UInt64] {
            return self.proposals[tick] ?? []
        }

        access(all) view
        fun getProposalDetails(proposalId: UInt64): Proposal? {
            return self.proposalDetails[proposalId]
        }

        /** ----- Write ----- */

        // TODO

        /** ----- Internal ----- */

        access(self)
        fun borrowProposalRef(proposalId: UInt64): &Proposal {
            return &self.proposalDetails[proposalId] as &Proposal?
                ?? panic("Proposal is not found")
        }
    }

    init() {
        let votesIdentifier = "FRC20VotesManager_".concat(self.account.address.toString())
        self.FRC20VotesManagerStoragePath = StoragePath(identifier: votesIdentifier)!
        self.FRC20VotesManagerPublicPath = PublicPath(identifier: votesIdentifier)!
        // create the resource
        self.account.save(<- create VotesManager(), to: self.FRC20VotesManagerStoragePath)
        self.account.link<&VotesManager{VotesManagerPublic}>(
            self.FRC20VotesManagerPublicPath,
            target: self.FRC20VotesManagerStoragePath
        )

        let voterIdentifier = "FRC20Voter_".concat(self.account.address.toString())
        self.VoterStoragePath = StoragePath(identifier: voterIdentifier)!
        self.VoterPublicPath = PublicPath(identifier: voterIdentifier)!

        emit ContractInitialized()
    }
}
