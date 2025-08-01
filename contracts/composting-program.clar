;; Composting Program Coordination Contract
;; Manages organic waste collection and processing into useful compost

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-INPUT (err u401))
(define-constant ERR-NOT-FOUND (err u402))
(define-constant ERR-INSUFFICIENT-CAPACITY (err u403))
(define-constant ERR-INVALID-SCHEDULE (err u404))

;; Data Variables
(define-data-var total-collection-sites uint u0)
(define-data-var total-processing-facilities uint u0)
(define-data-var total-batches uint u0)
(define-data-var total-sales uint u0)

;; Data Maps
(define-map collection-sites
  { site-id: uint }
  {
    name: (string-ascii 100),
    address: (string-ascii 200),
    coordinator: principal,
    capacity: uint,
    current-volume: uint,
    collection-frequency: uint, ;; days between collections
    last-collection: uint,
    active: bool
  }
)

(define-map processing-facilities
  { facility-id: uint }
  {
    name: (string-ascii 100),
    operator: principal,
    processing-capacity: uint,
    current-load: uint,
    compost-quality-rating: uint, ;; 1-10 scale
    certifications: (list 5 (string-ascii 50)),
    active: bool
  }
)

(define-map collection-schedules
  { site-id: uint, week: uint }
  {
    scheduled-date: uint,
    assigned-collector: principal,
    estimated-volume: uint,
    actual-volume: uint,
    completed: bool,
    quality-score: uint
  }
)

(define-map compost-batches
  { batch-id: uint }
  {
    facility-id: uint,
    organic-waste-volume: uint,
    additives-used: (string-ascii 200),
    start-date: uint,
    estimated-completion: uint,
    actual-completion: uint,
    quality-grade: (string-ascii 10), ;; "A", "B", "C"
    volume-produced: uint,
    status: (string-ascii 20) ;; "processing", "curing", "ready", "sold"
  }
)

(define-map compost-sales
  { sale-id: uint }
  {
    batch-id: uint,
    buyer: principal,
    volume-sold: uint,
    price-per-unit: uint,
    total-amount: uint,
    delivery-address: (string-ascii 200),
    sale-date: uint,
    delivered: bool
  }
)

(define-map quality-metrics
  { facility-id: uint, month: uint, year: uint }
  {
    batches-produced: uint,
    average-quality: uint,
    total-volume: uint,
    customer-satisfaction: uint,
    efficiency-rating: uint
  }
)

;; Public Functions

;; Register collection site
(define-public (register-collection-site (name (string-ascii 100)) (address (string-ascii 200)) (capacity uint) (collection-frequency uint))
  (let ((site-id (+ (var-get total-collection-sites) u1)))
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> capacity u0) ERR-INVALID-INPUT)
    (asserts! (> collection-frequency u0) ERR-INVALID-INPUT)
    (map-set collection-sites
      { site-id: site-id }
      {
        name: name,
        address: address,
        coordinator: tx-sender,
        capacity: capacity,
        current-volume: u0,
        collection-frequency: collection-frequency,
        last-collection: u0,
        active: true
      }
    )
    (var-set total-collection-sites site-id)
    (ok site-id)
  )
)

;; Register processing facility
(define-public (register-processing-facility (name (string-ascii 100)) (processing-capacity uint) (certifications (list 5 (string-ascii 50))))
  (let ((facility-id (+ (var-get total-processing-facilities) u1)))
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> processing-capacity u0) ERR-INVALID-INPUT)
    (map-set processing-facilities
      { facility-id: facility-id }
      {
        name: name,
        operator: tx-sender,
        processing-capacity: processing-capacity,
        current-load: u0,
        compost-quality-rating: u5, ;; Default middle rating
        certifications: certifications,
        active: true
      }
    )
    (var-set total-processing-facilities facility-id)
    (ok facility-id)
  )
)

;; Schedule collection
(define-public (schedule-collection (site-id uint) (week uint) (scheduled-date uint) (estimated-volume uint))
  (let ((site (unwrap! (map-get? collection-sites { site-id: site-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get coordinator site)) ERR-NOT-AUTHORIZED)
    (asserts! (> scheduled-date block-height) ERR-INVALID-SCHEDULE)
    (asserts! (<= estimated-volume (get capacity site)) ERR-INSUFFICIENT-CAPACITY)
    (map-set collection-schedules
      { site-id: site-id, week: week }
      {
        scheduled-date: scheduled-date,
        assigned-collector: tx-sender,
        estimated-volume: estimated-volume,
        actual-volume: u0,
        completed: false,
        quality-score: u0
      }
    )
    (ok true)
  )
)

;; Complete collection
(define-public (complete-collection (site-id uint) (week uint) (actual-volume uint) (quality-score uint))
  (let ((schedule (unwrap! (map-get? collection-schedules { site-id: site-id, week: week }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get assigned-collector schedule)) ERR-NOT-AUTHORIZED)
    (asserts! (<= quality-score u10) ERR-INVALID-INPUT)
    (map-set collection-schedules
      { site-id: site-id, week: week }
      (merge schedule {
        actual-volume: actual-volume,
        completed: true,
        quality-score: quality-score
      })
    )
    ;; Update site volume
    (try! (update-site-volume site-id actual-volume))
    (ok true)
  )
)

;; Start compost batch
(define-public (start-compost-batch (facility-id uint) (organic-waste-volume uint) (additives-used (string-ascii 200)) (estimated-completion uint))
  (let ((facility (unwrap! (map-get? processing-facilities { facility-id: facility-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get operator facility)) ERR-NOT-AUTHORIZED)
    (asserts! (> organic-waste-volume u0) ERR-INVALID-INPUT)
    (asserts! (> estimated-completion block-height) ERR-INVALID-INPUT)
    (let ((batch-id (+ (var-get total-batches) u1)))
      (map-set compost-batches
        { batch-id: batch-id }
        {
          facility-id: facility-id,
          organic-waste-volume: organic-waste-volume,
          additives-used: additives-used,
          start-date: block-height,
          estimated-completion: estimated-completion,
          actual-completion: u0,
          quality-grade: "C", ;; Default grade
          volume-produced: u0,
          status: "processing"
        }
      )
      (var-set total-batches batch-id)
      (try! (update-facility-load facility-id organic-waste-volume))
      (ok batch-id)
    )
  )
)

;; Complete compost batch
(define-public (complete-compost-batch (batch-id uint) (quality-grade (string-ascii 10)) (volume-produced uint))
  (let ((batch (unwrap! (map-get? compost-batches { batch-id: batch-id }) ERR-NOT-FOUND)))
    (let ((facility (unwrap! (map-get? processing-facilities { facility-id: (get facility-id batch) }) ERR-NOT-FOUND)))
      (asserts! (is-eq tx-sender (get operator facility)) ERR-NOT-AUTHORIZED)
      (asserts! (is-eq (get status batch) "processing") ERR-INVALID-INPUT)
      (asserts! (> volume-produced u0) ERR-INVALID-INPUT)
      (map-set compost-batches
        { batch-id: batch-id }
        (merge batch {
          actual-completion: block-height,
          quality-grade: quality-grade,
          volume-produced: volume-produced,
          status: "ready"
        })
      )
      (ok true)
    )
  )
)

;; Record compost sale
(define-public (record-compost-sale (batch-id uint) (buyer principal) (volume-sold uint) (price-per-unit uint) (delivery-address (string-ascii 200)))
  (let ((batch (unwrap! (map-get? compost-batches { batch-id: batch-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq (get status batch) "ready") ERR-INVALID-INPUT)
    (asserts! (<= volume-sold (get volume-produced batch)) ERR-INVALID-INPUT)
    (asserts! (> price-per-unit u0) ERR-INVALID-INPUT)
    (let ((sale-id (+ (var-get total-sales) u1)))
      (let ((total-amount (* volume-sold price-per-unit)))
        (map-set compost-sales
          { sale-id: sale-id }
          {
            batch-id: batch-id,
            buyer: buyer,
            volume-sold: volume-sold,
            price-per-unit: price-per-unit,
            total-amount: total-amount,
            delivery-address: delivery-address,
            sale-date: block-height,
            delivered: false
          }
        )
        (var-set total-sales sale-id)
        (ok sale-id)
      )
    )
  )
)

;; Private Functions

;; Update site volume after collection
(define-private (update-site-volume (site-id uint) (collected-volume uint))
  (let ((site (unwrap! (map-get? collection-sites { site-id: site-id }) ERR-NOT-FOUND)))
    (map-set collection-sites
      { site-id: site-id }
      (merge site {
        current-volume: (if (>= (get current-volume site) collected-volume)
                          (- (get current-volume site) collected-volume)
                          u0),
        last-collection: block-height
      })
    )
    (ok true)
  )
)

;; Update facility processing load
(define-private (update-facility-load (facility-id uint) (additional-load uint))
  (let ((facility (unwrap! (map-get? processing-facilities { facility-id: facility-id }) ERR-NOT-FOUND)))
    (map-set processing-facilities
      { facility-id: facility-id }
      (merge facility { current-load: (+ (get current-load facility) additional-load) })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get collection site details
(define-read-only (get-collection-site (site-id uint))
  (map-get? collection-sites { site-id: site-id })
)

;; Get processing facility details
(define-read-only (get-processing-facility (facility-id uint))
  (map-get? processing-facilities { facility-id: facility-id })
)

;; Get collection schedule
(define-read-only (get-collection-schedule (site-id uint) (week uint))
  (map-get? collection-schedules { site-id: site-id, week: week })
)

;; Get compost batch details
(define-read-only (get-compost-batch (batch-id uint))
  (map-get? compost-batches { batch-id: batch-id })
)

;; Get compost sale details
(define-read-only (get-compost-sale (sale-id uint))
  (map-get? compost-sales { sale-id: sale-id })
)

;; Get quality metrics
(define-read-only (get-quality-metrics (facility-id uint) (month uint) (year uint))
  (map-get? quality-metrics { facility-id: facility-id, month: month, year: year })
)

;; Get total collection sites
(define-read-only (get-total-collection-sites)
  (var-get total-collection-sites)
)

;; Get total processing facilities
(define-read-only (get-total-processing-facilities)
  (var-get total-processing-facilities)
)

;; Get total batches
(define-read-only (get-total-batches)
  (var-get total-batches)
)

;; Get total sales
(define-read-only (get-total-sales)
  (var-get total-sales)
)
