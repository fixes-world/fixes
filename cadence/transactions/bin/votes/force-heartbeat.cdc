import "FRC20Votes"

transaction {
    prepare(acct: AuthAccount) {
        let votesManager = acct.borrow<&FRC20Votes.VotesManager>(from: FRC20Votes.FRC20VotesManagerStoragePath)
            ?? panic("Missing VotesManager")
        votesManager.forceHeartbeat()
    }
}
