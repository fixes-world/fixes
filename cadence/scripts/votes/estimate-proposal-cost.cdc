import "Fixes"
import "FixesInscriptionFactory"
import "FRC20VoteCommands"

access(all)
fun main(
    tick: String,
    commands: [UInt8],
    params: [{String: String}]
): UFix64 {
    let commandTypes: [FRC20VoteCommands.CommandType] = []

    var total = 0.0
    var i = 0
    while i < commands.length {
        if let cmdType = FRC20VoteCommands.CommandType(rawValue: commands[i]) {
            let cmdParams = params[i]
            cmdParams["tick"] = tick
            let insDataStrArr = FRC20VoteCommands.buildInscriptionStringsByCommand(cmdType, cmdParams)
            for datastr in insDataStrArr {
                total = total + FixesInscriptionFactory.estimateFrc20InsribeCost(datastr)
            }
        }
        i = i + 1
    }
    return total
}
