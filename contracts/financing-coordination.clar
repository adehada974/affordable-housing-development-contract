;; Development Financing & Subsidy Coordination Smart Contract
;; This contract manages financial aspects of affordable housing development,
;; including subsidy pools, loans, investor management, and fund disbursement.

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u2001))
(define-constant ERR_INSUFFICIENT_FUNDS (err u2002))
(define-constant ERR_INVALID_AMOUNT (err u2003))
(define-constant ERR_LOAN_NOT_FOUND (err u2004))
(define-constant ERR_LOAN_ALREADY_EXISTS (err u2005))
(define-constant ERR_INVESTOR_NOT_WHITELISTED (err u2006))
(define-constant ERR_SUBSIDY_POOL_NOT_FOUND (err u2007))
(define-constant ERR_DISBURSEMENT_NOT_FOUND (err u2008))
(define-constant ERR_ALREADY_APPROVED (err u2009))
(define-constant ERR_NOT_DUE_YET (err u2010))
(define-constant ERR_ALREADY_DISBURSED (err u2011))
(define-constant ERR_INVALID_STATUS (err u2012))
(define-constant ERR_EXCEEDS_POOL_LIMIT (err u2013))

;; Contract data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-loan-id uint u1)
(define-data-var next-subsidy-pool-id uint u1)
(define-data-var next-disbursement-id uint u1)
(define-data-var total-funds-managed uint u0)
(define-data-var emergency-pause bool false)

;; Constants
(define-constant MAX_INTEREST_RATE u1000) ;; 10.00% (basis points)
(define-constant MIN_LOAN_AMOUNT u100000000) ;; 1,000 STX (microSTX)
(define-constant MAX_LOAN_DURATION u52560) ;; ~1 year in blocks

;; Subsidy pool management
(define-map subsidy-pools uint {
  name: (string-ascii 100),
  description: (string-ascii 500),
  total-allocated: uint,
  total-disbursed: uint,
  funding-source: (string-ascii 50),
  created-at: uint,
  expires-at: uint,
  manager: principal,
  is-active: bool
})

;; Low-interest loan ledger
(define-map loans uint {
  borrower: principal,
  amount: uint,
  interest-rate: uint,
  duration-blocks: uint,
  created-at: uint,
  due-date: uint,
  status: (string-ascii 20),
  collateral-amount: uint,
  purpose: (string-ascii 200),
  approved-by: (optional principal)
})

;; Loan repayment tracking
(define-map loan-payments {loan-id: uint, payment-number: uint} {
  amount: uint,
  paid-at: uint,
  remaining-balance: uint,
  interest-portion: uint,
  principal-portion: uint
})

;; Investor whitelist and contributions
(define-map whitelisted-investors principal {
  whitelisted-at: uint,
  total-contributed: uint,
  investment-tier: (string-ascii 20),
  risk-tolerance: (string-ascii 20),
  is-active: bool
})

;; Investment contributions
(define-map investor-contributions {investor: principal, contribution-id: uint} {
  amount: uint,
  contributed-at: uint,
  investment-type: (string-ascii 50),
  expected-return-rate: uint,
  lock-period-blocks: uint
})

;; Fund disbursement scheduling
(define-map scheduled-disbursements uint {
  recipient: principal,
  amount: uint,
  pool-id: uint,
  scheduled-for: uint,
  purpose: (string-ascii 200),
  status: (string-ascii 20),
  approved-by: principal,
  disbursed-at: (optional uint)
})

;; Audit trail for all financial transactions
(define-map audit-trail uint {
  transaction-type: (string-ascii 50),
  amount: uint,
  from-address: (optional principal),
  to-address: (optional principal),
  timestamp: uint,
  reference-id: uint,
  notes: (string-ascii 300)
})

(define-data-var next-audit-id uint u1)

;; Add investor to whitelist
(define-public (whitelist-investor 
  (investor principal)
  (investment-tier (string-ascii 20))
  (risk-tolerance (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (var-get emergency-pause)) ERR_UNAUTHORIZED)
    (map-set whitelisted-investors investor {
      whitelisted-at: block-height,
      total-contributed: u0,
      investment-tier: investment-tier,
      risk-tolerance: risk-tolerance,
      is-active: true
    })
    (print {event: "investor-whitelisted", investor: investor, tier: investment-tier})
    (ok true)
  )
)

;; Create new subsidy pool
(define-public (create-subsidy-pool
  (name (string-ascii 100))
  (description (string-ascii 500))
  (total-allocated uint)
  (funding-source (string-ascii 50))
  (duration-blocks uint))
  (let ((pool-id (var-get next-subsidy-pool-id)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> total-allocated u0) ERR_INVALID_AMOUNT)
    (asserts! (> duration-blocks u0) ERR_INVALID_AMOUNT)
    (asserts! (not (var-get emergency-pause)) ERR_UNAUTHORIZED)
    (map-set subsidy-pools pool-id {
      name: name,
      description: description,
      total-allocated: total-allocated,
      total-disbursed: u0,
      funding-source: funding-source,
      created-at: block-height,
      expires-at: (+ block-height duration-blocks),
      manager: tx-sender,
      is-active: true
    })
    (var-set next-subsidy-pool-id (+ pool-id u1))
    (var-set total-funds-managed (+ (var-get total-funds-managed) total-allocated))
    (unwrap-panic (record-audit-transaction "subsidy-pool-created" total-allocated none none pool-id 
           (concat "Created pool: " name)))
    (print {event: "subsidy-pool-created", pool-id: pool-id, allocated: total-allocated})
    (ok pool-id)
  )
)

;; Apply for low-interest loan
(define-public (apply-for-loan
  (amount uint)
  (duration-blocks uint)
  (collateral-amount uint)
  (purpose (string-ascii 200)))
  (let 
    ((loan-id (var-get next-loan-id))
     (interest-rate (calculate-interest-rate amount duration-blocks)))
    (asserts! (>= amount MIN_LOAN_AMOUNT) ERR_INVALID_AMOUNT)
    (asserts! (<= duration-blocks MAX_LOAN_DURATION) ERR_INVALID_AMOUNT)
    (asserts! (> collateral-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (not (var-get emergency-pause)) ERR_UNAUTHORIZED)
    (map-set loans loan-id {
      borrower: tx-sender,
      amount: amount,
      interest-rate: interest-rate,
      duration-blocks: duration-blocks,
      created-at: block-height,
      due-date: (+ block-height duration-blocks),
      status: "pending",
      collateral-amount: collateral-amount,
      purpose: purpose,
      approved-by: none
    })
    (var-set next-loan-id (+ loan-id u1))
    (unwrap-panic (record-audit-transaction "loan-application" amount (some tx-sender) none loan-id purpose))
    (print {event: "loan-applied", loan-id: loan-id, borrower: tx-sender, amount: amount})
    (ok loan-id)
  )
)

;; Approve loan (owner or designated approver)
(define-public (approve-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status loan) "pending") ERR_ALREADY_APPROVED)
    (asserts! (not (var-get emergency-pause)) ERR_UNAUTHORIZED)
    (map-set loans loan-id (merge loan {
      status: "approved",
      approved-by: (some tx-sender)
    }))
    (unwrap-panic (record-audit-transaction "loan-approved" (get amount loan) 
           (some tx-sender) (some (get borrower loan)) loan-id "Loan approved"))
    (print {event: "loan-approved", loan-id: loan-id, approver: tx-sender})
    (ok true)
  )
)

;; Record investor contribution
(define-public (record-investment
  (investor principal)
  (amount uint)
  (investment-type (string-ascii 50))
  (expected-return-rate uint)
  (lock-period-blocks uint))
  (let 
    ((investor-info (unwrap! (map-get? whitelisted-investors investor) ERR_INVESTOR_NOT_WHITELISTED))
     (contribution-id (+ (get total-contributed investor-info) u1)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (get is-active investor-info) ERR_INVESTOR_NOT_WHITELISTED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (not (var-get emergency-pause)) ERR_UNAUTHORIZED)
    (map-set investor-contributions {investor: investor, contribution-id: contribution-id} {
      amount: amount,
      contributed-at: block-height,
      investment-type: investment-type,
      expected-return-rate: expected-return-rate,
      lock-period-blocks: lock-period-blocks
    })
    (map-set whitelisted-investors investor 
      (merge investor-info {total-contributed: (+ (get total-contributed investor-info) amount)}))
    (var-set total-funds-managed (+ (var-get total-funds-managed) amount))
    (unwrap-panic (record-audit-transaction "investment-recorded" amount (some investor) none contribution-id 
           investment-type))
    (print {event: "investment-recorded", investor: investor, amount: amount})
    (ok contribution-id)
  )
)

;; Schedule fund disbursement
(define-public (schedule-disbursement
  (recipient principal)
  (amount uint)
  (pool-id uint)
  (scheduled-for uint)
  (purpose (string-ascii 200)))
  (let 
    ((disbursement-id (var-get next-disbursement-id))
     (pool (unwrap! (map-get? subsidy-pools pool-id) ERR_SUBSIDY_POOL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (get is-active pool) ERR_SUBSIDY_POOL_NOT_FOUND)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (- (get total-allocated pool) (get total-disbursed pool)) amount) ERR_INSUFFICIENT_FUNDS)
    (asserts! (>= scheduled-for block-height) ERR_INVALID_AMOUNT)
    (asserts! (not (var-get emergency-pause)) ERR_UNAUTHORIZED)
    (map-set scheduled-disbursements disbursement-id {
      recipient: recipient,
      amount: amount,
      pool-id: pool-id,
      scheduled-for: scheduled-for,
      purpose: purpose,
      status: "scheduled",
      approved-by: tx-sender,
      disbursed-at: none
    })
    (var-set next-disbursement-id (+ disbursement-id u1))
    (unwrap-panic (record-audit-transaction "disbursement-scheduled" amount none (some recipient) 
           disbursement-id purpose))
    (print {event: "disbursement-scheduled", disbursement-id: disbursement-id, recipient: recipient})
    (ok disbursement-id)
  )
)

;; Execute scheduled disbursement
(define-public (execute-disbursement (disbursement-id uint))
  (let 
    ((disbursement (unwrap! (map-get? scheduled-disbursements disbursement-id) ERR_DISBURSEMENT_NOT_FOUND))
     (pool (unwrap! (map-get? subsidy-pools (get pool-id disbursement)) ERR_SUBSIDY_POOL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status disbursement) "scheduled") ERR_ALREADY_DISBURSED)
    (asserts! (<= (get scheduled-for disbursement) block-height) ERR_NOT_DUE_YET)
    (asserts! (not (var-get emergency-pause)) ERR_UNAUTHORIZED)
    (map-set scheduled-disbursements disbursement-id 
      (merge disbursement {
        status: "disbursed",
        disbursed-at: (some block-height)
      }))
    (map-set subsidy-pools (get pool-id disbursement)
      (merge pool {total-disbursed: (+ (get total-disbursed pool) (get amount disbursement))}))
    (unwrap-panic (record-audit-transaction "funds-disbursed" (get amount disbursement) 
           none (some (get recipient disbursement)) disbursement-id (get purpose disbursement)))
    (print {event: "funds-disbursed", disbursement-id: disbursement-id, 
            recipient: (get recipient disbursement), amount: (get amount disbursement)})
    (ok true)
  )
)

;; Emergency pause function
(define-public (toggle-emergency-pause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set emergency-pause (not (var-get emergency-pause)))
    (print {event: "emergency-pause-toggled", paused: (var-get emergency-pause)})
    (ok (var-get emergency-pause))
  )
)

;; Helper function to calculate interest rate based on amount and duration
(define-private (calculate-interest-rate (amount uint) (duration-blocks uint))
  (let 
    ((base-rate u200) ;; 2.00% base rate
     (amount-factor (if (> amount u500000000) u50 u0)) ;; -0.5% for large loans
     (duration-factor (/ duration-blocks u5256))) ;; Additional rate based on duration
    (+ base-rate (- duration-factor amount-factor))
  )
)

;; Helper function to record audit transactions
(define-private (record-audit-transaction 
  (tx-type (string-ascii 50))
  (amount uint)
  (from-addr (optional principal))
  (to-addr (optional principal))
  (ref-id uint)
  (notes (string-ascii 300)))
  (let ((audit-id (var-get next-audit-id)))
    (map-set audit-trail audit-id {
      transaction-type: tx-type,
      amount: amount,
      from-address: from-addr,
      to-address: to-addr,
      timestamp: block-height,
      reference-id: ref-id,
      notes: notes
    })
    (var-set next-audit-id (+ audit-id u1))
    (ok audit-id)
  )
)

;; Read-only functions
(define-read-only (get-subsidy-pool (pool-id uint))
  (map-get? subsidy-pools pool-id)
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)

(define-read-only (get-investor-info (investor principal))
  (map-get? whitelisted-investors investor)
)

(define-read-only (get-disbursement (disbursement-id uint))
  (map-get? scheduled-disbursements disbursement-id)
)

(define-read-only (get-audit-record (audit-id uint))
  (map-get? audit-trail audit-id)
)

(define-read-only (get-contract-stats)
  {
    total-funds-managed: (var-get total-funds-managed),
    emergency-pause: (var-get emergency-pause),
    next-loan-id: (var-get next-loan-id),
    next-subsidy-pool-id: (var-get next-subsidy-pool-id),
    next-disbursement-id: (var-get next-disbursement-id),
    contract-owner: (var-get contract-owner)
  }
)


;; title: financing-coordination
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

