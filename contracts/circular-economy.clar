;; Circular Economy Material Flow Contract
;; Tracks materials through reuse, repair, and recycling cycles

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-INPUT (err u501))
(define-constant ERR-NOT-FOUND (err u502))
(define-constant ERR-INVALID-TRANSITION (err u503))
(define-constant ERR-INSUFFICIENT-MATERIALS (err u504))

;; Data Variables
(define-data-var total-materials uint u0)
(define-data-var total-businesses uint u0)
(define-data-var total-transactions uint u0)
(define-data-var total-impact-reports uint u0)

;; Data Maps
(define-map materials
  { material-id: uint }
  {
    material-type: (string-ascii 50), ;; "plastic", "metal", "textile", "electronic", "organic"
    current-owner: principal,
    original-manufacturer: principal,
    current-condition: (string-ascii 20), ;; "new", "good", "fair", "poor", "broken"
    lifecycle-stage: (string-ascii 20), ;; "production", "use", "reuse", "repair", "recycle", "disposal"
    location: (string-ascii 100),
    estimated-value: uint,
    carbon-footprint: uint,
    created-at: uint,
    last-updated: uint
  }
)

(define-map circular-businesses
  { business-id: uint }
  {
    name: (string-ascii 100),
    owner: principal,
    business-type: (string-ascii 50), ;; "repair", "refurbish", "upcycle", "marketplace", "recycler"
    specializations: (list 5 (string-ascii 50)),
    location: (string-ascii 100),
    reputation-score: uint,
    total-transactions: uint,
    active: bool
  }
)

(define-map material-transactions
  { transaction-id: uint }
  {
    material-id: uint,
    from-owner: principal,
    to-owner: principal,
    transaction-type: (string-ascii 20), ;; "sale", "repair", "donation", "exchange", "recycle"
    price: uint,
    condition-before: (string-ascii 20),
    condition-after: (string-ascii 20),
    business-id: uint,
    timestamp: uint,
    verified: bool
  }
)

(define-map reuse-opportunities
  { opportunity-id: uint }
  {
    material-type: (string-ascii 50),
    posted-by: principal,
    description: (string-ascii 200),
    quantity-available: uint,
    condition: (string-ascii 20),
    asking-price: uint,
    location: (string-ascii 100),
    expires-at: uint,
    claimed: bool
  }
)

(define-map repair-services
  { service-id: uint }
  {
    business-id: uint,
    material-types: (list 10 (string-ascii 50)),
    service-description: (string-ascii 200),
    average-cost: uint,
    turnaround-time: uint,
    success-rate: uint,
    available: bool
  }
)

(define-map economic-impact-reports
  { report-id: uint }
  {
    reporting-period: uint, ;; month/year combination
    total-materials-tracked: uint,
    total-value-retained: uint,
    carbon-emissions-avoided: uint,
    jobs-created: uint,
    waste-diverted: uint,
    circular-revenue: uint
  }
)

;; Public Functions

;; Register new material in the system
(define-public (register-material (material-type (string-ascii 50)) (condition (string-ascii 20)) (location (string-ascii 100)) (estimated-value uint) (carbon-footprint uint))
  (let ((material-id (+ (var-get total-materials) u1)))
    (asserts! (> (len material-type) u0) ERR-INVALID-INPUT)
    (asserts! (> estimated-value u0) ERR-INVALID-INPUT)
    (map-set materials
      { material-id: material-id }
      {
        material-type: material-type,
        current-owner: tx-sender,
        original-manufacturer: tx-sender,
        current-condition: condition,
        lifecycle-stage: "use",
        location: location,
        estimated-value: estimated-value,
        carbon-footprint: carbon-footprint,
        created-at: block-height,
        last-updated: block-height
      }
    )
    (var-set total-materials material-id)
    (ok material-id)
  )
)

;; Register circular economy business
(define-public (register-business (name (string-ascii 100)) (business-type (string-ascii 50)) (specializations (list 5 (string-ascii 50))) (location (string-ascii 100)))
  (let ((business-id (+ (var-get total-businesses) u1)))
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len business-type) u0) ERR-INVALID-INPUT)
    (map-set circular-businesses
      { business-id: business-id }
      {
        name: name,
        owner: tx-sender,
        business-type: business-type,
        specializations: specializations,
        location: location,
        reputation-score: u50, ;; Start with neutral score
        total-transactions: u0,
        active: true
      }
    )
    (var-set total-businesses business-id)
    (ok business-id)
  )
)

;; Record material transaction
(define-public (record-transaction (material-id uint) (to-owner principal) (transaction-type (string-ascii 20)) (price uint) (condition-after (string-ascii 20)) (business-id uint))
  (let ((material (unwrap! (map-get? materials { material-id: material-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get current-owner material)) ERR-NOT-AUTHORIZED)
    (let ((transaction-id (+ (var-get total-transactions) u1)))
      ;; Record transaction
      (map-set material-transactions
        { transaction-id: transaction-id }
        {
          material-id: material-id,
          from-owner: tx-sender,
          to-owner: to-owner,
          transaction-type: transaction-type,
          price: price,
          condition-before: (get current-condition material),
          condition-after: condition-after,
          business-id: business-id,
          timestamp: block-height,
          verified: false
        }
      )
      ;; Update material ownership and condition
      (map-set materials
        { material-id: material-id }
        (merge material {
          current-owner: to-owner,
          current-condition: condition-after,
          lifecycle-stage: (get-new-lifecycle-stage transaction-type),
          last-updated: block-height
        })
      )
      (var-set total-transactions transaction-id)
      (try! (update-business-stats business-id))
      (ok transaction-id)
    )
  )
)

;; Post reuse opportunity
(define-public (post-reuse-opportunity (material-type (string-ascii 50)) (description (string-ascii 200)) (quantity uint) (condition (string-ascii 20)) (asking-price uint) (location (string-ascii 100)) (expires-at uint))
  (let ((opportunity-id (+ (var-get total-transactions) u1))) ;; Reusing counter for simplicity
    (asserts! (> (len material-type) u0) ERR-INVALID-INPUT)
    (asserts! (> quantity u0) ERR-INVALID-INPUT)
    (asserts! (> expires-at block-height) ERR-INVALID-INPUT)
    (map-set reuse-opportunities
      { opportunity-id: opportunity-id }
      {
        material-type: material-type,
        posted-by: tx-sender,
        description: description,
        quantity-available: quantity,
        condition: condition,
        asking-price: asking-price,
        location: location,
        expires-at: expires-at,
        claimed: false
      }
    )
    (ok opportunity-id)
  )
)

;; Register repair service
(define-public (register-repair-service (business-id uint) (material-types (list 10 (string-ascii 50))) (service-description (string-ascii 200)) (average-cost uint) (turnaround-time uint))
  (let ((business (unwrap! (map-get? circular-businesses { business-id: business-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner business)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get business-type business) "repair") ERR-INVALID-INPUT)
    (let ((service-id business-id)) ;; Using business-id as service-id for simplicity
      (map-set repair-services
        { service-id: service-id }
        {
          business-id: business-id,
          material-types: material-types,
          service-description: service-description,
          average-cost: average-cost,
          turnaround-time: turnaround-time,
          success-rate: u90, ;; Default success rate
          available: true
        }
      )
      (ok service-id)
    )
  )
)

;; Generate economic impact report
(define-public (generate-impact-report (reporting-period uint) (total-value-retained uint) (carbon-emissions-avoided uint) (jobs-created uint) (waste-diverted uint) (circular-revenue uint))
  (let ((report-id (+ (var-get total-impact-reports) u1)))
    ;; In practice, would verify tx-sender is authorized to generate reports
    (map-set economic-impact-reports
      { report-id: report-id }
      {
        reporting-period: reporting-period,
        total-materials-tracked: (var-get total-materials),
        total-value-retained: total-value-retained,
        carbon-emissions-avoided: carbon-emissions-avoided,
        jobs-created: jobs-created,
        waste-diverted: waste-diverted,
        circular-revenue: circular-revenue
      }
    )
    (var-set total-impact-reports report-id)
    (ok report-id)
  )
)

;; Private Functions

;; Determine new lifecycle stage based on transaction type
(define-private (get-new-lifecycle-stage (transaction-type (string-ascii 20)))
  (if (is-eq transaction-type "repair")
    "repair"
    (if (is-eq transaction-type "recycle")
      "recycle"
      (if (is-eq transaction-type "donation")
        "reuse"
        "use"
      )
    )
  )
)

;; Update business transaction statistics
(define-private (update-business-stats (business-id uint))
  (let ((business (unwrap! (map-get? circular-businesses { business-id: business-id }) ERR-NOT-FOUND)))
    (map-set circular-businesses
      { business-id: business-id }
      (merge business { total-transactions: (+ (get total-transactions business) u1) })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get material details
(define-read-only (get-material (material-id uint))
  (map-get? materials { material-id: material-id })
)

;; Get business details
(define-read-only (get-business (business-id uint))
  (map-get? circular-businesses { business-id: business-id })
)

;; Get transaction details
(define-read-only (get-transaction (transaction-id uint))
  (map-get? material-transactions { transaction-id: transaction-id })
)

;; Get reuse opportunity
(define-read-only (get-reuse-opportunity (opportunity-id uint))
  (map-get? reuse-opportunities { opportunity-id: opportunity-id })
)

;; Get repair service
(define-read-only (get-repair-service (service-id uint))
  (map-get? repair-services { service-id: service-id })
)

;; Get economic impact report
(define-read-only (get-impact-report (report-id uint))
  (map-get? economic-impact-reports { report-id: report-id })
)

;; Get material lifecycle history (simplified - would need more complex implementation)
(define-read-only (get-material-lifecycle (material-id uint))
  (map-get? materials { material-id: material-id })
)

;; Get total materials
(define-read-only (get-total-materials)
  (var-get total-materials)
)

;; Get total businesses
(define-read-only (get-total-businesses)
  (var-get total-businesses)
)

;; Get total transactions
(define-read-only (get-total-transactions)
  (var-get total-transactions)
)

;; Get total impact reports
(define-read-only (get-total-impact-reports)
  (var-get total-impact-reports)
)
