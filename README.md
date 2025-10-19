🗳️ Silent-Voting DAO

Overview

Silent-Voting DAO is a decentralized autonomous organization (DAO) smart contract built in Clarity that implements a commit–reveal voting scheme to ensure privacy and fairness in on-chain governance.
Members can create proposals, vote secretly using hashed commitments, and later reveal their votes for final tallying — preventing premature disclosure of voting preferences.

🧩 Features

Private (Silent) Voting: Votes are hidden during the commit phase and revealed only afterward.

Commit–Reveal Scheme: Ensures vote secrecy using a hash of the voter’s choice and a nonce.

Membership Control: Only DAO members can create proposals or vote.

Proposal Lifecycle Management: Each proposal progresses through commit, reveal, and finalized phases automatically based on block height.

Automatic Validation: Prevents double voting, invalid reveals, and unauthorized participation.

⚙️ Contract Structure
Constants

VOTING_DURATION – Number of blocks for the voting (commit) phase (~24 hours).

REVEAL_DURATION – Number of blocks for the reveal phase (~12 hours).

CONTRACT_OWNER – The principal that deployed the contract (auto-added as first member).

ERR_* – Set of well-defined error codes for consistent validation.

Data Variables

proposal-counter – Tracks the total number of proposals created.

Data Maps

members – Stores registered DAO members.

proposals – Stores proposal data and their state (creator, title, votes, etc.).

vote-commits – Records each member’s hashed vote commitments.

vote-reveals – Stores revealed votes and corresponding nonces.

🧠 Workflow
1. Membership

Only the contract owner can add members.

(add-member new-member)

2. Create Proposal

Members can create proposals with a title and description.

(create-proposal title description)

3. Commit Vote

During the voting phase, members submit a commitment hash:

(commit-vote proposal-id vote-hash)


The vote-hash is generated off-chain using:

hash160({ vote: <true|false>, nonce: <uint> })

4. Reveal Vote

After voting ends, members reveal their vote and nonce:

(reveal-vote proposal-id vote nonce)


The contract verifies that hash(vote, nonce) matches the committed hash.

5. Finalize Proposal

Once the reveal phase ends, any member can finalize the proposal:

(finalize-proposal proposal-id)


The result includes whether the proposal passed, plus vote counts.

🔍 Read-Only Functions
Function	Description
is-member(user)	Checks if a principal is a member.
get-proposal(proposal-id)	Fetches proposal details.
get-vote-commit(proposal-id, voter)	Returns a voter's committed hash.
get-vote-reveal(proposal-id, voter)	Returns a voter's revealed vote and nonce.
get-proposal-count()	Returns total number of proposals created.
get-voting-phase(proposal-id)	Returns "commit", "reveal", "ended", or "not-exists".
create-vote-hash(vote, nonce)	Utility to verify or generate the commit hash.

🛡️ Error Codes
Code	Meaning
u100	Unauthorized caller
u101	Already voted
u102	Proposal not found
u103	Voting or reveal period ended
u104	Reveal not started
u105	Invalid reveal (hash mismatch)
u106	Not a member
u107	Already a member
u108	Empty title
u109	Empty description
u110	Invalid hash length
🧪 Example Voting Flow (Simplified)
;; 1. Owner adds a member
(add-member 'ST2C2...XYZ)

;; 2. Member creates a proposal
(create-proposal "Add liquidity to DAO fund" "Proposal to allocate funds to treasury pool")

;; 3. Member commits a hashed vote
(commit-vote u1 0xabcdef1234567890...) ;; precomputed hash of (vote, nonce)

;; 4. After voting ends, member reveals
(reveal-vote u1 true u12345)

;; 5. After reveal ends, finalize
(finalize-proposal u1)

🔒 Security Notes

All votes remain hidden until the reveal phase.

Nonces prevent vote hash collisions or reverse engineering.

Invalid or mismatched reveals are automatically rejected.

Only verified members can participate in any DAO action.

🏁 Future Improvements

Proposal execution hooks for on-chain actions.

Weighted voting based on DAO tokens.

Time-based proposal expiration.

Off-chain frontend integration for commit–reveal UX.

📄 License

MIT License