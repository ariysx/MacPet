import Foundation

enum Feeling: String, Codable, CaseIterable {
    case scared, sick, sleepy, hungry, sad, excited, content

    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

enum Feelings {
    /// Worked out from state every tick. The first rule that matches wins.
    static func resolve(_ pet: Pet) -> Feeling {
        if (pet.held && pet.traits.courage == .timid) || pet.fight == .fleeing || pet.fight == .retreated {
            return .scared
        }
        if pet.sickRemaining > 0 || pet.health < 30 { return .sick }
        if pet.isAsleep || pet.energy < 25 { return .sleepy }
        if pet.hunger < 30 { return .hungry }
        if pet.happiness < 30 { return .sad }
        if pet.excitedRemaining > 0 { return .excited }
        return .content
    }
}
