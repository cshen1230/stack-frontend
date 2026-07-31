import Foundation

/// Who may add players to a session.
enum InvitePolicy: String, Codable, Sendable, CaseIterable {
    /// Anyone already in the session adds directly. The default, and right for a group of
    /// friends where approval would be pure friction.
    case open
    /// A second person has to agree before the add lands.
    case approval
    /// Only the creator adds.
    case ownerOnly = "owner_only"

    var displayName: String {
        switch self {
        case .open: return "Anyone can add"
        case .approval: return "Needs approval"
        case .ownerOnly: return "Host only"
        }
    }
}

/// Resolves who can approve a pending add, and when.
///
/// The problem this solves: plain owner-approval fails at exactly the moment it matters. It's
/// 5pm, the game is at 6, you're at nine and need one more — and the host is driving, or on
/// court, or asleep. Nobody gets added, and the session plays a man short because a permission
/// setting outlived its usefulness.
///
/// The fix is not to drop approval but to notice what approval is actually for: **two people
/// agreeing**, rather than one specific person agreeing. So that invariant holds all the way
/// through, and only the question of *who counts as the second person* widens as the game gets
/// close. Far out, it has to be the host. Near start, anyone already in the session will do —
/// they're the ones standing on the court, and they have better information than the host does.
///
/// The proposer never counts as their own approver, at any distance. That's what stops this
/// degrading into "no approval at all".
struct SessionApproval {
    let policy: InvitePolicy
    let startsAt: Date
    let creatorId: UUID

    /// Inside this window before start, any confirmed participant can approve. Long enough to
    /// cover getting ready and travelling, short enough that it isn't the normal path.
    static let handoverWindow: TimeInterval = 3 * 60 * 60

    /// True once the host is no longer the only person who can approve.
    func hasHandedOver(at now: Date = Date()) -> Bool {
        startsAt.timeIntervalSince(now) <= Self.handoverWindow
    }

    /// Does an add by this person need a second pair of eyes at all?
    func requiresApproval(proposer: UUID, at now: Date = Date()) -> Bool {
        switch policy {
        case .open:
            return false
        case .ownerOnly, .approval:
            // The host adding people is the authority the setting exists to protect.
            return proposer != creatorId
        }
    }

    /// Can `candidate` approve an add proposed by `proposer`?
    ///
    /// `isParticipant` is the caller's answer for the candidate — the roster lives on the
    /// server, and this type stays a pure rule so it can be reasoned about and tested.
    func canApprove(
        candidate: UUID,
        proposedBy proposer: UUID,
        candidateIsParticipant: Bool,
        at now: Date = Date()
    ) -> Bool {
        // Approving your own request is not two people agreeing.
        guard candidate != proposer else { return false }

        switch policy {
        case .open:
            return false // Nothing to approve.
        case .ownerOnly:
            return candidate == creatorId
        case .approval:
            if candidate == creatorId { return true }
            return hasHandedOver(at: now) && candidateIsParticipant
        }
    }

    /// What a pending request should tell the person who made it.
    func pendingExplanation(at now: Date = Date()) -> String {
        switch policy {
        case .open:
            return ""
        case .ownerOnly:
            return "Waiting for the host to approve."
        case .approval:
            if hasHandedOver(at: now) {
                return "Waiting for anyone in the session to approve."
            }
            let hours = Int((startsAt.timeIntervalSince(now) - Self.handoverWindow) / 3600)
            if hours >= 1 {
                return "Waiting for the host. In \(hours)h, anyone in the session can approve."
            }
            return "Waiting for the host. Soon, anyone in the session can approve."
        }
    }
}
