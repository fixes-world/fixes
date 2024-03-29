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
    let voter: &FRC20Votes.VoterIdentity
    let flowVault: &FlowToken.Vault

    prepare(acct: AuthAccount) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        /** ------------- Start -- FRC20 Semi NFT Collection Initialization ------------  */
        // ensure resource
        if acct.borrow<&AnyResource>(from: FRC20SemiNFT.CollectionStoragePath) == nil {
            acct.save(<- FRC20SemiNFT.createEmptyCollection(), to: FRC20SemiNFT.CollectionStoragePath)
        }

        // link to public capability
        // @deprecated after Cadence 1.0
        if acct
            .getCapability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(FRC20SemiNFT.CollectionPublicPath)
            .borrow() == nil {
            acct.unlink(FRC20SemiNFT.CollectionPublicPath)
            acct.link<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(
                FRC20SemiNFT.CollectionPublicPath,
                target: FRC20SemiNFT.CollectionStoragePath
            )
            // Link private path (will be deprecated in Cadence 1.0)
            acct.unlink(FRC20SemiNFT.CollectionPrivatePath)
            acct.link<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
                FRC20SemiNFT.CollectionPrivatePath,
                target: FRC20SemiNFT.CollectionStoragePath
            )
        }
        /** ------------- End ---------------------------------------------------------- */

        /** ------------- Initialize Voter Resource - Start -------------------- */
        if acct.borrow<&AnyResource>(from: FRC20Votes.VoterStoragePath) == nil {
            // get private cap
            let cap = acct.getCapability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(FRC20SemiNFT.CollectionPrivatePath)
            acct.save(<- FRC20Votes.createVoter(cap), to: FRC20Votes.VoterStoragePath)
        }

        // link to public capability
        // @deprecated after Cadence 1.0
        if acct
            .getCapability<&FRC20Votes.VoterIdentity{FRC20Votes.VoterPublic}>(FRC20Votes.VoterPublicPath)
            .borrow() == nil {
            acct.unlink(FRC20Votes.VoterPublicPath)
            acct.link<&FRC20Votes.VoterIdentity{FRC20Votes.VoterPublic, FRC20SemiNFT.FRC20SemiNFTCollectionPublic, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}>(
                FRC20Votes.VoterPublicPath,
                target: FRC20Votes.VoterStoragePath
            )
        }
        /** ------------- End -------------------------------------------------- */

        self.voter = acct.borrow<&FRC20Votes.VoterIdentity>(from: FRC20Votes.VoterStoragePath)
            ?? panic("Could not borrow a reference to the Voter Resource!")

        // Get a reference to the signer's stored vault
        self.flowVault = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
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
