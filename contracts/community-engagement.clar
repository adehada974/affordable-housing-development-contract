;; Community Engagement Smart Contract for Affordable Housing Development
;; This contract manages community surveys, proposals, voting, and progress tracking
;; to ensure democratic participation in housing development decisions.

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_SURVEY_NOT_FOUND (err u1002))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u1003))
(define-constant ERR_ALREADY_VOTED (err u1004))
(define-constant ERR_VOTING_CLOSED (err u1005))
(define-constant ERR_INVALID_STATUS (err u1006))
(define-constant ERR_INSUFFICIENT_VOTES (err u1007))
(define-constant ERR_MILESTONE_NOT_FOUND (err u1008))
(define-constant ERR_INVALID_PARAMETERS (err u1009))

;; Contract data variables
(define-data-var next-survey-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var next-milestone-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Survey data structure
(define-map surveys uint {
  title: (string-ascii 100),
  description: (string-ascii 500),
  creator: principal,
  created-at: uint,
  expires-at: uint,
  is-active: bool,
  response-count: uint
})

;; Survey responses
(define-map survey-responses {survey-id: uint, respondent: principal} {
  responses: (string-ascii 1000),
  submitted-at: uint,
  satisfaction-score: uint
})

;; Proposal data structure
(define-map proposals uint {
  title: (string-ascii 100),
  description: (string-ascii 1000),
  creator: principal,
  created-at: uint,
  voting-ends-at: uint,
  votes-for: uint,
  votes-against: uint,
  status: (string-ascii 20),
  required-threshold: uint,
  category: (string-ascii 50)
})

;; Voting records
(define-map votes {proposal-id: uint, voter: principal} {
  vote: bool,
  voted-at: uint,
  weight: uint
})

;; Community member registration
(define-map community-members principal {
  registered-at: uint,
  voting-power: uint,
  reputation-score: uint,
  is-active: bool
})

;; Project milestones for progress tracking
(define-map project-milestones uint {
  title: (string-ascii 100),
  description: (string-ascii 500),
  target-date: uint,
  completion-date: (optional uint),
  status: (string-ascii 20),
  assigned-to: principal,
  community-feedback: (string-ascii 1000)
})

;; Register a new community member
(define-public (register-member (member principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set community-members member {
      registered-at: block-height,
      voting-power: u1,
      reputation-score: u100,
      is-active: true
    }))
  )
)

;; Create a new community survey
(define-public (create-survey 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (duration-blocks uint))
  (let 
    ((survey-id (var-get next-survey-id)))
    (asserts! (> (len title) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> duration-blocks u0) ERR_INVALID_PARAMETERS)
    (map-set surveys survey-id {
      title: title,
      description: description,
      creator: tx-sender,
      created-at: block-height,
      expires-at: (+ block-height duration-blocks),
      is-active: true,
      response-count: u0
    })
    (var-set next-survey-id (+ survey-id u1))
    (print {event: "survey-created", survey-id: survey-id, creator: tx-sender})
    (ok survey-id)
  )
)

;; Submit survey response
(define-public (submit-survey-response 
  (survey-id uint)
  (responses (string-ascii 1000))
  (satisfaction-score uint))
  (let 
    ((survey (unwrap! (map-get? surveys survey-id) ERR_SURVEY_NOT_FOUND))
     (member (unwrap! (map-get? community-members tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (get is-active survey) ERR_VOTING_CLOSED)
    (asserts! (<= block-height (get expires-at survey)) ERR_VOTING_CLOSED)
    (asserts! (<= satisfaction-score u10) ERR_INVALID_PARAMETERS)
    (asserts! (get is-active member) ERR_UNAUTHORIZED)
    (map-set survey-responses {survey-id: survey-id, respondent: tx-sender} {
      responses: responses,
      submitted-at: block-height,
      satisfaction-score: satisfaction-score
    })
    (map-set surveys survey-id 
      (merge survey {response-count: (+ (get response-count survey) u1)}))
    (print {event: "survey-response-submitted", survey-id: survey-id, respondent: tx-sender})
    (ok true)
  )
)

;; Create a community proposal
(define-public (create-proposal
  (title (string-ascii 100))
  (description (string-ascii 1000))
  (voting-duration-blocks uint)
  (required-threshold uint)
  (category (string-ascii 50)))
  (let 
    ((proposal-id (var-get next-proposal-id))
     (member (unwrap! (map-get? community-members tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (> (len title) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> voting-duration-blocks u0) ERR_INVALID_PARAMETERS)
    (asserts! (> required-threshold u0) ERR_INVALID_PARAMETERS)
    (asserts! (get is-active member) ERR_UNAUTHORIZED)
    (map-set proposals proposal-id {
      title: title,
      description: description,
      creator: tx-sender,
      created-at: block-height,
      voting-ends-at: (+ block-height voting-duration-blocks),
      votes-for: u0,
      votes-against: u0,
      status: "active",
      required-threshold: required-threshold,
      category: category
    })
    (var-set next-proposal-id (+ proposal-id u1))
    (print {event: "proposal-created", proposal-id: proposal-id, creator: tx-sender})
    (ok proposal-id)
  )
)

;; Vote on a proposal
(define-public (vote-on-proposal (proposal-id uint) (support bool))
  (let 
    ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
     (member (unwrap! (map-get? community-members tx-sender) ERR_UNAUTHORIZED))
     (existing-vote (map-get? votes {proposal-id: proposal-id, voter: tx-sender})))
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
    (asserts! (<= block-height (get voting-ends-at proposal)) ERR_VOTING_CLOSED)
    (asserts! (get is-active member) ERR_UNAUTHORIZED)
    (let ((voting-power (get voting-power member)))
      (map-set votes {proposal-id: proposal-id, voter: tx-sender} {
        vote: support,
        voted-at: block-height,
        weight: voting-power
      })
      (if support
        (map-set proposals proposal-id 
          (merge proposal {votes-for: (+ (get votes-for proposal) voting-power)}))
        (map-set proposals proposal-id 
          (merge proposal {votes-against: (+ (get votes-against proposal) voting-power)})))
      (print {event: "vote-cast", proposal-id: proposal-id, voter: tx-sender, support: support})
      (ok true)
    )
  )
)

;; Finalize proposal voting
(define-public (finalize-proposal (proposal-id uint))
  (let 
    ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (is-eq (get status proposal) "active") ERR_INVALID_STATUS)
    (asserts! (> block-height (get voting-ends-at proposal)) ERR_VOTING_CLOSED)
    (let 
      ((votes-for (get votes-for proposal))
       (votes-against (get votes-against proposal))
       (threshold (get required-threshold proposal))
       (new-status (if (>= votes-for threshold) "approved" "rejected")))
      (map-set proposals proposal-id (merge proposal {status: new-status}))
      (print {event: "proposal-finalized", proposal-id: proposal-id, status: new-status})
      (ok new-status)
    )
  )
)

;; Create project milestone
(define-public (create-milestone
  (title (string-ascii 100))
  (description (string-ascii 500))
  (target-date uint)
  (assigned-to principal))
  (let 
    ((milestone-id (var-get next-milestone-id)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> (len title) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> target-date block-height) ERR_INVALID_PARAMETERS)
    (map-set project-milestones milestone-id {
      title: title,
      description: description,
      target-date: target-date,
      completion-date: none,
      status: "pending",
      assigned-to: assigned-to,
      community-feedback: ""
    })
    (var-set next-milestone-id (+ milestone-id u1))
    (print {event: "milestone-created", milestone-id: milestone-id})
    (ok milestone-id)
  )
)

;; Update milestone progress
(define-public (update-milestone-status 
  (milestone-id uint)
  (new-status (string-ascii 20))
  (completion-date (optional uint)))
  (let 
    ((milestone (unwrap! (map-get? project-milestones milestone-id) ERR_MILESTONE_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) 
                  (is-eq tx-sender (get assigned-to milestone))) ERR_UNAUTHORIZED)
    (map-set project-milestones milestone-id 
      (merge milestone {
        status: new-status,
        completion-date: completion-date
      }))
    (print {event: "milestone-updated", milestone-id: milestone-id, status: new-status})
    (ok true)
  )
)

;; Add community feedback to milestone
(define-public (add-milestone-feedback
  (milestone-id uint)
  (feedback (string-ascii 1000)))
  (let 
    ((milestone (unwrap! (map-get? project-milestones milestone-id) ERR_MILESTONE_NOT_FOUND))
     (member (unwrap! (map-get? community-members tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (get is-active member) ERR_UNAUTHORIZED)
    (map-set project-milestones milestone-id 
      (merge milestone {community-feedback: feedback}))
    (print {event: "milestone-feedback-added", milestone-id: milestone-id, contributor: tx-sender})
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-survey (survey-id uint))
  (map-get? surveys survey-id)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-member-info (member principal))
  (map-get? community-members member)
)

(define-read-only (get-milestone (milestone-id uint))
  (map-get? project-milestones milestone-id)
)

(define-read-only (get-survey-response (survey-id uint) (respondent principal))
  (map-get? survey-responses {survey-id: survey-id, respondent: respondent})
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-contract-info)
  {
    next-survey-id: (var-get next-survey-id),
    next-proposal-id: (var-get next-proposal-id),
    next-milestone-id: (var-get next-milestone-id),
    contract-owner: (var-get contract-owner)
  }
)


;; title: community-engagement
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

