import "FlowToken"
import "FungibleToken"
import "NonFungibleToken"
import "MetadataViews"
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20SemiNFT"
import "FRC20Votes"
import "FRC20VoteCommands"

transaction(
    tick: String,
    title: String,
    description: String,
    discussionLink: String?,
    executableThreshold: UFix64,
    beginningTime: UFix64,
    endingTime: UFix64,
    commands: [UInt8],
    messages: [String],
    params: [{String: String}]
) {
    let voter: auth(NonFungibleToken.Withdraw) &FRC20Votes.VoterIdentity
    let flowVault: auth(FungibleToken.Withdraw) &FlowToken.Vault

    prepare(acct: auth(Storage, Capabilities) &Account) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.storage.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        /** ------------- Start -- FRC20 Semi NFT Collection Initialization ------------  */
        // ensure resource
        if acct.storage.borrow<&AnyResource>(from: FRC20SemiNFT.CollectionStoragePath) == nil {
            acct.storage.save(<- FRC20SemiNFT.createEmptyCollection(nftType: Type<@FRC20SemiNFT.NFT>()), to: FRC20SemiNFT.CollectionStoragePath)
        }

        // link to public capability
        if acct
            .capabilities.get<&FRC20SemiNFT.Collection>(FRC20SemiNFT.CollectionPublicPath)
            .borrow() == nil {
            acct.capabilities.unpublish(FRC20SemiNFT.CollectionPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20SemiNFT.Collection>(
                    FRC20SemiNFT.CollectionStoragePath
                ),
                at: FRC20SemiNFT.CollectionPublicPath
            )
        }
        /** ------------- End ---------------------------------------------------------- */

        /** ------------- Initialize Voter Resource - Start -------------------- */
        if acct.storage.borrow<&AnyResource>(from: FRC20Votes.VoterStoragePath) == nil {
            // get private cap
            let cap = acct.capabilities.storage
                .issue<auth(NonFungibleToken.Withdraw, NonFungibleToken.Update) &FRC20SemiNFT.Collection>(FRC20SemiNFT.CollectionStoragePath)
            acct.storage.save(<- FRC20Votes.createVoter(cap), to: FRC20Votes.VoterStoragePath)
        }

        // link to public capability
        if acct
            .capabilities
            .get<&FRC20Votes.VoterIdentity>(FRC20Votes.VoterPublicPath)
            .borrow() == nil {
            acct.capabilities.unpublish(FRC20Votes.VoterPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20Votes.VoterIdentity>(
                    FRC20Votes.VoterStoragePath
                ),
                at: FRC20Votes.VoterPublicPath
            )
        }
        /** ------------- End -------------------------------------------------- */

        self.voter = acct.storage.borrow<auth(NonFungibleToken.Withdraw) &FRC20Votes.VoterIdentity>(from: FRC20Votes.VoterStoragePath)
            ?? panic("Could not borrow a reference to the Voter Resource!")

        // Get a reference to the signer's stored vault
        self.flowVault = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")
    }

    pre {
        messages.length == commands.length: "The number of messages must be equal to the number of commands"
        messages.length == params.length: "The number of messages must be equal to the number of params"
    }

    execute {
        // Singleton Resources
        let voteMgr = FRC20Votes.borrowVotesManager()

        let inscriptions: @[[Fixes.Inscription]] <- []
        let commandTypes: [FRC20VoteCommands.CommandType] = []

        var i = 0
        while i < commands.length {
            let command = commands[i]
            let insArr: @[Fixes.Inscription] <- []
            let cmdType = FRC20VoteCommands.CommandType(rawValue: command) ?? panic("Invalid command type")
            commandTypes.append(cmdType)
            let cmdParams = params[i]
            cmdParams["tick"] = tick
            let insDataStrArr = FRC20VoteCommands.buildInscriptionStringsByCommand(cmdType, cmdParams)
            for dataStr in insDataStrArr {
                // estimate the required storage
                let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)
                // Withdraw tokens from the signer's stored vault
                let costReserve <- self.flowVault.withdraw(amount: estimatedReqValue)
                // create the inscription
                let ins <- FixesInscriptionFactory.createFrc20Inscription(
                    dataStr,
                    <- (costReserve as! @FlowToken.Vault),
                )
                insArr.append(<- ins)
            }
            inscriptions.append(<- insArr)
            i = i + 1
        }

        // create the proposal
        voteMgr.createProposal(
            voter: self.voter,
            tick: tick,
            title: title,
            description: description,
            discussionLink: discussionLink,
            executableThreshold: executableThreshold,
            beginningTime: beginningTime,
            endingTime: endingTime,
            commands: commandTypes,
            messages: messages,
            inscriptions: <- inscriptions
        )
    }
}
