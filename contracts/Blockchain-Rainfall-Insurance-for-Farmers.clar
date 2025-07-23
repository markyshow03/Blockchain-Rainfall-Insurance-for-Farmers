(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-payment (err u103))
(define-constant err-policy-expired (err u104))
(define-constant err-claim-already-processed (err u105))
(define-constant err-threshold-not-met (err u106))
(define-constant err-invalid-data (err u107))

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
