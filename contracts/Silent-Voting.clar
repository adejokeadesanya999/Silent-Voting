;; title: Silent-Voting DAO
;; version: 1.0.0
;; summary: A DAO with silent voting using commit-reveal scheme
;; description: Members can vote on proposals without revealing choices until reveal phase

;; constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VOTED (err u101))
(define-constant ERR_PROPOSAL_NOT_EXISTS (err u102))
(define-constant ERR_VOTING_ENDED (err u103))
(define-constant ERR_REVEAL_NOT_STARTED (err u104))
(define-constant ERR_INVALID_REVEAL (err u105))
(define-constant ERR_NOT_MEMBER (err u106))
(define-constant ERR_ALREADY_MEMBER (err u107))
(define-constant ERR_EMPTY_TITLE (err u108))
(define-constant ERR_EMPTY_DESCRIPTION (err u109))
(define-constant ERR_INVALID_HASH_LENGTH (err u110))

(define-constant CONTRACT_OWNER tx-sender)
(define-constant VOTING_DURATION u144) ;; ~24 hours in blocks
(define-constant REVEAL_DURATION u72)  ;; ~12 hours in blocks

;; data vars
(define-data-var proposal-counter uint u0)

;; data maps
(define-map members principal bool)

(define-map proposals uint {
    title: (string-ascii 100),
    description: (string-ascii 500),
    creator: principal,
    start-block: uint,
    end-block: uint,
    reveal-end-block: uint,
    yes-votes: uint,
    no-votes: uint,
    total-commits: uint,
    finalized: bool
})

(define-map vote-commits { proposal-id: uint, voter: principal } (buff 32))
(define-map vote-reveals { proposal-id: uint, voter: principal } { vote: bool, nonce: uint })

;; public functions

(define-public (add-member (new-member principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (is-none (map-get? members new-member)) ERR_ALREADY_MEMBER)
        (map-set members new-member true)
        (ok true)
    )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))
    (let (
        (proposal-id (+ (var-get proposal-counter) u1))
        (start-block block-height)
        (end-block (+ block-height VOTING_DURATION))
        (reveal-end (+ end-block REVEAL_DURATION))
    )
        (asserts! (is-member tx-sender) ERR_NOT_MEMBER)
        (asserts! (> (len title) u0) ERR_EMPTY_TITLE)
        (asserts! (> (len description) u0) ERR_EMPTY_DESCRIPTION)
        (map-set proposals proposal-id {
            title: title,
            description: description,
            creator: tx-sender,
            start-block: start-block,
            end-block: end-block,
            reveal-end-block: reveal-end,
            yes-votes: u0,
            no-votes: u0,
            total-commits: u0,
            finalized: false
        })
        (var-set proposal-counter proposal-id)
        (ok proposal-id)
    )
)

(define-public (commit-vote (proposal-id uint) (vote-hash (buff 32)))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_EXISTS))
    )
        (asserts! (is-member tx-sender) ERR_NOT_MEMBER)
        (asserts! (<= block-height (get end-block proposal)) ERR_VOTING_ENDED)
        (asserts! (is-none (map-get? vote-commits { proposal-id: proposal-id, voter: tx-sender })) ERR_ALREADY_VOTED)
        (asserts! (is-eq (len vote-hash) u32) ERR_INVALID_HASH_LENGTH)

        (map-set vote-commits { proposal-id: proposal-id, voter: tx-sender } vote-hash)
        (map-set proposals proposal-id 
            (merge proposal { total-commits: (+ (get total-commits proposal) u1) })
        )
        (ok true)
    )
)

(define-public (reveal-vote (proposal-id uint) (vote bool) (nonce uint))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_EXISTS))
        (expected-hash (create-vote-hash vote nonce))
        (committed-hash (unwrap! (map-get? vote-commits { proposal-id: proposal-id, voter: tx-sender }) ERR_UNAUTHORIZED))
    )
        (asserts! (is-member tx-sender) ERR_NOT_MEMBER)
        (asserts! (> block-height (get end-block proposal)) ERR_REVEAL_NOT_STARTED)
        (asserts! (<= block-height (get reveal-end-block proposal)) ERR_VOTING_ENDED)
        (asserts! (is-eq expected-hash committed-hash) ERR_INVALID_REVEAL)
        (asserts! (is-none (map-get? vote-reveals { proposal-id: proposal-id, voter: tx-sender })) ERR_ALREADY_VOTED)

        (map-set vote-reveals { proposal-id: proposal-id, voter: tx-sender } { vote: vote, nonce: nonce })
        (map-set proposals proposal-id 
            (merge proposal {
                yes-votes: (if vote (+ (get yes-votes proposal) u1) (get yes-votes proposal)),
                no-votes: (if vote (get no-votes proposal) (+ (get no-votes proposal) u1))
            })
        )
        (ok true)
    )
)

(define-public (finalize-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_EXISTS))
    )
        (asserts! (is-member tx-sender) ERR_NOT_MEMBER)
        (asserts! (> block-height (get reveal-end-block proposal)) ERR_VOTING_ENDED)
        (asserts! (not (get finalized proposal)) ERR_ALREADY_VOTED)

        (map-set proposals proposal-id (merge proposal { finalized: true }))
        (ok {
            passed: (> (get yes-votes proposal) (get no-votes proposal)),
            yes-votes: (get yes-votes proposal),
            no-votes: (get no-votes proposal),
            total-commits: (get total-commits proposal)
        })
    )
)

;; read only functions

(define-read-only (is-member (user principal))
    (default-to false (map-get? members user))
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-vote-commit (proposal-id uint) (voter principal))
    (map-get? vote-commits { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-vote-reveal (proposal-id uint) (voter principal))
    (map-get? vote-reveals { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-proposal-count)
    (var-get proposal-counter)
)

(define-read-only (get-voting-phase (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal 
        (if (<= block-height (get end-block proposal))
            "commit"
            (if (<= block-height (get reveal-end-block proposal))
                "reveal"
                "ended"
            )
        )
        "not-exists"
    )
)

(define-read-only (create-vote-hash (vote bool) (nonce uint))
    (hash160 (unwrap-panic (to-consensus-buff? { vote: vote, nonce: nonce })))
)

;; private functions

;; Initialize contract owner as first member
(map-set members CONTRACT_OWNER true)
