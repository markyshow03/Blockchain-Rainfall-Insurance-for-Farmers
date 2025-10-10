(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-payment (err u103))
(define-constant err-policy-expired (err u104))
(define-constant err-claim-already-processed (err u105))
(define-constant err-threshold-not-met (err u106))
(define-constant err-invalid-data (err u107))

(define-constant base-premium-rate u5)
(define-constant risk-multiplier-low u100)
(define-constant risk-multiplier-medium u150)
(define-constant risk-multiplier-high u200)
(define-constant minimum-premium u50)

(define-constant err-pool-not-found (err u108))
(define-constant err-already-member (err u109))
(define-constant err-not-member (err u110))
(define-constant err-pool-full (err u111))
(define-constant max-pool-members u10)

(define-data-var next-pool-id uint u1)

(define-data-var next-policy-id uint u1)
(define-data-var contract-balance uint u0)
(define-data-var rainfall-oracle principal tx-sender)

(define-map policies
  { policy-id: uint }
  {
    farmer: principal,
    premium: uint,
    coverage: uint,
    rainfall-threshold: uint,
    start-block: uint,
    end-block: uint,
    location: (string-ascii 50),
    active: bool
  }
)

(define-map rainfall-data
  { location: (string-ascii 50), period: uint }
  { rainfall-amount: uint, recorded-at: uint, verified: bool }
)

(define-map claims
  { policy-id: uint }
  { amount: uint, processed: bool, claim-block: uint }
)

(define-public (set-rainfall-oracle (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set rainfall-oracle new-oracle)
    (ok true)
  )
)

(define-public (create-policy 
  (premium uint) 
  (coverage uint) 
  (rainfall-threshold uint) 
  (duration-blocks uint) 
  (location (string-ascii 50))
)
  (let
    (
      (policy-id (var-get next-policy-id))
      (start-block stacks-block-height)
      (end-block (+ stacks-block-height duration-blocks))
    )
    (asserts! (>= (stx-get-balance tx-sender) premium) err-insufficient-payment)
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    (map-set policies 
      { policy-id: policy-id }
      {
        farmer: tx-sender,
        premium: premium,
        coverage: coverage,
        rainfall-threshold: rainfall-threshold,
        start-block: start-block,
        end-block: end-block,
        location: location,
        active: true
      }
    )
    (var-set next-policy-id (+ policy-id u1))
    (var-set contract-balance (+ (var-get contract-balance) premium))
    (ok policy-id)
  )
)

(define-public (record-rainfall 
  (location (string-ascii 50)) 
  (period uint) 
  (rainfall-amount uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get rainfall-oracle)) err-owner-only)
    (asserts! (> rainfall-amount u0) err-invalid-data)
    (map-set rainfall-data
      { location: location, period: period }
      { 
        rainfall-amount: rainfall-amount, 
        recorded-at: stacks-block-height, 
        verified: true 
      }
    )
    (ok true)
  )
)

(define-public (file-claim (policy-id uint) (period uint))
  (let
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) err-not-found))
      (location (get location policy))
      (rainfall-info (unwrap! (map-get? rainfall-data { location: location, period: period }) err-not-found))
      (existing-claim (map-get? claims { policy-id: policy-id }))
    )
    (asserts! (is-eq tx-sender (get farmer policy)) err-owner-only)
    (asserts! (get active policy) err-policy-expired)
    (asserts! (>= stacks-block-height (get start-block policy)) err-invalid-data)
    (asserts! (<= stacks-block-height (get end-block policy)) err-policy-expired)
    (asserts! (is-none existing-claim) err-claim-already-processed)
    (asserts! (get verified rainfall-info) err-invalid-data)
    (asserts! (< (get rainfall-amount rainfall-info) (get rainfall-threshold policy)) err-threshold-not-met)
    
    (map-set claims
      { policy-id: policy-id }
      { 
        amount: (get coverage policy), 
        processed: false, 
        claim-block: stacks-block-height 
      }
    )
    (ok true)
  )
)

(define-public (process-claim (policy-id uint))
  (let
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) err-not-found))
      (claim (unwrap! (map-get? claims { policy-id: policy-id }) err-not-found))
      (payout-amount (get amount claim))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get processed claim)) err-claim-already-processed)
    (asserts! (>= (var-get contract-balance) payout-amount) err-insufficient-payment)
    
    (try! (as-contract (stx-transfer? payout-amount tx-sender (get farmer policy))))
    (map-set claims
      { policy-id: policy-id }
      (merge claim { processed: true })
    )
    (map-set policies
      { policy-id: policy-id }
      (merge policy { active: false })
    )
    (var-set contract-balance (- (var-get contract-balance) payout-amount))
    (ok payout-amount)
  )
)

(define-public (cancel-policy (policy-id uint))
  (let
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) err-not-found))
      (refund-amount (/ (get premium policy) u2))
    )
    (asserts! (is-eq tx-sender (get farmer policy)) err-owner-only)
    (asserts! (get active policy) err-policy-expired)
    (asserts! (>= (var-get contract-balance) refund-amount) err-insufficient-payment)
    
    (try! (as-contract (stx-transfer? refund-amount tx-sender (get farmer policy))))
    (map-set policies
      { policy-id: policy-id }
      (merge policy { active: false })
    )
    (var-set contract-balance (- (var-get contract-balance) refund-amount))
    (ok refund-amount)
  )
)

(define-read-only (get-policy (policy-id uint))
  (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-rainfall-data (location (string-ascii 50)) (period uint))
  (map-get? rainfall-data { location: location, period: period })
)

(define-read-only (get-claim (policy-id uint))
  (map-get? claims { policy-id: policy-id })
)

(define-read-only (get-contract-balance)
  (var-get contract-balance)
)

(define-read-only (get-next-policy-id)
  (var-get next-policy-id)
)

(define-read-only (get-rainfall-oracle)
  (var-get rainfall-oracle)
)


(define-map location-analytics
  { location: (string-ascii 50) }
  {
    total-policies: uint,
    total-premiums: uint,
    total-claims: uint,
    total-payouts: uint,
    active-policies: uint
  }
)

(define-map global-analytics
  { key: (string-ascii 20) }
  { value: uint }
)

(define-private (init-global-analytics)
  (begin
    (map-set global-analytics { key: "total-policies" } { value: u0 })
    (map-set global-analytics { key: "total-premiums" } { value: u0 })
    (map-set global-analytics { key: "total-claims" } { value: u0 })
    (map-set global-analytics { key: "total-payouts" } { value: u0 })
    (map-set global-analytics { key: "active-policies" } { value: u0 })
  )
)

(define-private (update-location-analytics-on-policy (location (string-ascii 50)) (premium uint))
  (let
    (
      (current-stats (default-to 
        { total-policies: u0, total-premiums: u0, total-claims: u0, total-payouts: u0, active-policies: u0 }
        (map-get? location-analytics { location: location })
      ))
    )
    (map-set location-analytics
      { location: location }
      {
        total-policies: (+ (get total-policies current-stats) u1),
        total-premiums: (+ (get total-premiums current-stats) premium),
        total-claims: (get total-claims current-stats),
        total-payouts: (get total-payouts current-stats),
        active-policies: (+ (get active-policies current-stats) u1)
      }
    )
  )
)

(define-private (update-global-analytics-on-policy (premium uint))
  (begin
    (map-set global-analytics { key: "total-policies" } 
      { value: (+ (get value (unwrap-panic (map-get? global-analytics { key: "total-policies" }))) u1) })
    (map-set global-analytics { key: "total-premiums" } 
      { value: (+ (get value (unwrap-panic (map-get? global-analytics { key: "total-premiums" }))) premium) })
    (map-set global-analytics { key: "active-policies" } 
      { value: (+ (get value (unwrap-panic (map-get? global-analytics { key: "active-policies" }))) u1) })
  )
)

(define-private (update-analytics-on-payout (location (string-ascii 50)) (payout uint))
  (let
    (
      (current-stats (unwrap-panic (map-get? location-analytics { location: location })))
    )
    (map-set location-analytics
      { location: location }
      (merge current-stats {
        total-claims: (+ (get total-claims current-stats) u1),
        total-payouts: (+ (get total-payouts current-stats) payout),
        active-policies: (- (get active-policies current-stats) u1)
      })
    )
    (map-set global-analytics { key: "total-claims" } 
      { value: (+ (get value (unwrap-panic (map-get? global-analytics { key: "total-claims" }))) u1) })
    (map-set global-analytics { key: "total-payouts" } 
      { value: (+ (get value (unwrap-panic (map-get? global-analytics { key: "total-payouts" }))) payout) })
    (map-set global-analytics { key: "active-policies" } 
      { value: (- (get value (unwrap-panic (map-get? global-analytics { key: "active-policies" }))) u1) })
  )
)

(define-read-only (get-location-analytics (location (string-ascii 50)))
  (map-get? location-analytics { location: location })
)

(define-read-only (get-global-analytics)
  {
    total-policies: (get value (unwrap-panic (map-get? global-analytics { key: "total-policies" }))),
    total-premiums: (get value (unwrap-panic (map-get? global-analytics { key: "total-premiums" }))),
    total-claims: (get value (unwrap-panic (map-get? global-analytics { key: "total-claims" }))),
    total-payouts: (get value (unwrap-panic (map-get? global-analytics { key: "total-payouts" }))),
    active-policies: (get value (unwrap-panic (map-get? global-analytics { key: "active-policies" })))
  }
)

(define-read-only (calculate-location-success-rate (location (string-ascii 50)))
  (let
    (
      (stats (map-get? location-analytics { location: location }))
    )
    (match stats
      analytics
        (if (> (get total-policies analytics) u0)
          (/ (* (get total-claims analytics) u100) (get total-policies analytics))
          u0
        )
      u0
    )
  )
)


(define-map location-risk-tier
  { location: (string-ascii 50) }
  { risk-level: uint, last-updated: uint }
)

(define-map coverage-pricing
  { coverage-tier: uint }
  { base-rate: uint, max-coverage: uint }
)

(define-private (init-pricing-tiers)
  (begin
    (map-set coverage-pricing { coverage-tier: u1 } { base-rate: u3, max-coverage: u1000 })
    (map-set coverage-pricing { coverage-tier: u2 } { base-rate: u4, max-coverage: u5000 })
    (map-set coverage-pricing { coverage-tier: u3 } { base-rate: u5, max-coverage: u10000 })
  )
)

(define-private (calculate-risk-tier (location (string-ascii 50)))
  (let
    (
      (location-stats (map-get? location-analytics { location: location }))
    )
    (match location-stats
      stats
        (let
          (
            (claim-rate (if (> (get total-policies stats) u0)
                         (/ (* (get total-claims stats) u100) (get total-policies stats))
                         u0))
          )
          (if (<= claim-rate u20) u1
            (if (<= claim-rate u40) u2 u3))
        )
      u2
    )
  )
)

(define-private (get-risk-multiplier (risk-tier uint))
  (if (is-eq risk-tier u1) risk-multiplier-low
    (if (is-eq risk-tier u2) risk-multiplier-medium risk-multiplier-high))
)

(define-private (get-coverage-tier (coverage uint))
  (if (<= coverage u1000) u1
    (if (<= coverage u5000) u2 u3))
)

(define-public (calculate-recommended-premium (coverage uint) (location (string-ascii 50)))
  (let
    (
      (risk-tier (calculate-risk-tier location))
      (coverage-tier (get-coverage-tier coverage))
      (coverage-info (unwrap! (map-get? coverage-pricing { coverage-tier: coverage-tier }) err-invalid-data))
      (base-calculation (/ (* coverage (get base-rate coverage-info)) u100))
      (risk-adjusted (/ (* base-calculation (get-risk-multiplier risk-tier)) u100))
      (final-premium (if (< risk-adjusted minimum-premium) minimum-premium risk-adjusted))
    )
    (ok final-premium)
  )
)

(define-public (update-location-risk (location (string-ascii 50)))
  (let
    (
      (new-risk-tier (calculate-risk-tier location))
    )
    (map-set location-risk-tier
      { location: location }
      { risk-level: new-risk-tier, last-updated: stacks-block-height }
    )
    (ok new-risk-tier)
  )
)

(define-read-only (get-location-risk (location (string-ascii 50)))
  (map-get? location-risk-tier { location: location })
)

(define-read-only (get-pricing-info (coverage uint) (location (string-ascii 50)))
  {
    recommended-premium: (unwrap-panic (calculate-recommended-premium coverage location)),
    risk-tier: (calculate-risk-tier location),
    coverage-tier: (get-coverage-tier coverage)
  }
)

(define-map insurance-pools
  { pool-id: uint }
  {
    name: (string-ascii 50),
    creator: principal,
    total-contributions: uint,
    total-coverage: uint,
    member-count: uint,
    active: bool,
    created-at: uint
  }
)

(define-map pool-members
  { pool-id: uint, member: principal }
  { contribution: uint, share-percentage: uint, joined-at: uint }
)

(define-public (create-insurance-pool (pool-name (string-ascii 50)) (initial-contribution uint))
  (let
    (
      (pool-id (var-get next-pool-id))
    )
    (asserts! (>= (stx-get-balance tx-sender) initial-contribution) err-insufficient-payment)
    (try! (stx-transfer? initial-contribution tx-sender (as-contract tx-sender)))
    (map-set insurance-pools
      { pool-id: pool-id }
      {
        name: pool-name,
        creator: tx-sender,
        total-contributions: initial-contribution,
        total-coverage: (* initial-contribution u10),
        member-count: u1,
        active: true,
        created-at: stacks-block-height
      }
    )
    (map-set pool-members
      { pool-id: pool-id, member: tx-sender }
      { contribution: initial-contribution, share-percentage: u100, joined-at: stacks-block-height }
    )
    (var-set next-pool-id (+ pool-id u1))
    (ok pool-id)
  )
)

(define-public (join-insurance-pool (pool-id uint) (contribution uint))
  (let
    (
      (pool (unwrap! (map-get? insurance-pools { pool-id: pool-id }) err-pool-not-found))
      (existing-membership (map-get? pool-members { pool-id: pool-id, member: tx-sender }))
      (new-total (+ (get total-contributions pool) contribution))
      (new-member-count (+ (get member-count pool) u1))
    )
    (asserts! (is-none existing-membership) err-already-member)
    (asserts! (get active pool) err-invalid-data)
    (asserts! (< (get member-count pool) max-pool-members) err-pool-full)
    (asserts! (>= (stx-get-balance tx-sender) contribution) err-insufficient-payment)
    (try! (stx-transfer? contribution tx-sender (as-contract tx-sender)))
    (map-set pool-members
      { pool-id: pool-id, member: tx-sender }
      { contribution: contribution, share-percentage: (/ (* contribution u100) new-total), joined-at: stacks-block-height }
    )
    (map-set insurance-pools
      { pool-id: pool-id }
      (merge pool { total-contributions: new-total, member-count: new-member-count, total-coverage: (* new-total u10) })
    )
    (ok true)
  )
)

(define-read-only (get-pool-info (pool-id uint))
  (map-get? insurance-pools { pool-id: pool-id })
)

(define-read-only (get-pool-membership (pool-id uint) (member principal))
  (map-get? pool-members { pool-id: pool-id, member: member })
)