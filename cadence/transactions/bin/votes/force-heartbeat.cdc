import "FRC20Votes"

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        let votesManager = acct.storage
            .borrow<auth(FRC20Votes.Admin) &FRC20Votes.VotesManager>(from: FRC20Votes.FRC20VotesManagerStoragePath)
            ?? panic("Missing VotesManager")
        votesManager.forceHeartbeat()
    }
}
