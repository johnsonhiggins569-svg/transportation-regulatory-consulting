;; Transportation Regulatory Compliance Management Contract
;; Handles regulation monitoring, policy interpretation, audit preparation, and training

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-REGULATION (err u101))
(define-constant ERR-INVALID-AUDIT (err u102))
(define-constant ERR-INVALID-TRAINING (err u103))
(define-constant MAX-REGULATIONS u500)
(define-constant COMPLIANCE-THRESHOLD u85)

(define-data-var regulation-counter uint u0)
(define-data-var audit-counter uint u0)
(define-data-var total-violations uint u0)

(define-map regulations
  { regulation-id: uint }
  {
    title: (string-ascii 128),
    category: (string-ascii 32),
    jurisdiction: (string-ascii 64),
    effective-date: uint,
    description: (string-ascii 256),
    status: (string-ascii 16)
  }
)

(define-map compliance-status
  { organization-id: uint }
  {
    owner: principal,
    compliance-score: uint,
    violations: uint,
    last-audit: uint,
    audit-status: (string-ascii 16)
  }
)

(define-map audit-records
  { audit-id: uint }
  {
    organization-id: uint,
    audit-date: uint,
    findings: uint,
    recommendation: (string-ascii 256),
    severity: (string-ascii 16)
  }
)

(define-map training-modules
  { training-id: uint }
  {
    title: (string-ascii 128),
    category: (string-ascii 32),
    duration: uint,
    completion-rate: uint,
    created-at: uint
  }
)

(define-map training-enrollment
  { enrollment-id: uint }
  {
    principal-addr: principal,
    training-id: uint,
    completion-date: (optional uint),
    status: (string-ascii 16)
  }
)

(define-public (add-regulation
  (title (string-ascii 128))
  (category (string-ascii 32))
  (jurisdiction (string-ascii 64))
  (description (string-ascii 256))
)
  (let
    (
      (new-id (+ (var-get regulation-counter) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (< new-id MAX-REGULATIONS) ERR-INVALID-REGULATION)
    (map-set regulations
      { regulation-id: new-id }
      {
        title: title,
        category: category,
        jurisdiction: jurisdiction,
        effective-date: burn-block-height,
        description: description,
        status: "active"
      }
    )
    (var-set regulation-counter new-id)
    (ok new-id)
  )
)

(define-public (register-organization (compliance-score uint))
  (let
    (
      (org-id (+ (var-get audit-counter) u1))
    )
    (asserts! (and (>= compliance-score u0) (<= compliance-score u100)) ERR-UNAUTHORIZED)
    (map-set compliance-status
      { organization-id: org-id }
      {
        owner: tx-sender,
        compliance-score: compliance-score,
        violations: u0,
        last-audit: burn-block-height,
        audit-status: "compliant"
      }
    )
    (ok org-id)
  )
)

(define-public (record-violation (organization-id uint))
  (let
    (
      (current (map-get? compliance-status { organization-id: organization-id }))
    )
    (match current
      org-data
      (begin
        (asserts! (is-eq tx-sender (get owner org-data)) ERR-UNAUTHORIZED)
        (map-set compliance-status
          { organization-id: organization-id }
          (merge org-data
            {
              violations: (+ (get violations org-data) u1),
              audit-status: (if (> (get violations org-data) u5) "non-compliant" "warning")
            }
          )
        )
        (var-set total-violations (+ (var-get total-violations) u1))
        (ok true)
      )
      ERR-INVALID-REGULATION
    )
  )
)

(define-public (conduct-audit
  (organization-id uint)
  (findings uint)
  (recommendation (string-ascii 256))
  (severity (string-ascii 16))
)
  (let
    (
      (audit-id (+ (var-get audit-counter) u1))
      (current (map-get? compliance-status { organization-id: organization-id }))
    )
    (match current
      org-data
      (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (map-set audit-records
          { audit-id: audit-id }
          {
            organization-id: organization-id,
            audit-date: burn-block-height,
            findings: findings,
            recommendation: recommendation,
            severity: severity
          }
        )
        (map-set compliance-status
          { organization-id: organization-id }
          (merge org-data { last-audit: burn-block-height })
        )
        (var-set audit-counter audit-id)
        (ok audit-id)
      )
      ERR-INVALID-REGULATION
    )
  )
)

(define-public (create-training-module
  (title (string-ascii 128))
  (category (string-ascii 32))
  (duration uint)
)
  (let
    (
      (training-id (+ (var-get audit-counter) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-set training-modules
      { training-id: training-id }
      {
        title: title,
        category: category,
        duration: duration,
        completion-rate: u0,
        created-at: burn-block-height
      }
    )
    (ok training-id)
  )
)

(define-public (enroll-in-training (training-id uint))
  (let
    (
      (enrollment-id (+ (var-get audit-counter) u1))
      (training (map-get? training-modules { training-id: training-id }))
    )
    (match training
      training-data
      (begin
        (map-set training-enrollment
          { enrollment-id: enrollment-id }
          {
            principal-addr: tx-sender,
            training-id: training-id,
            completion-date: none,
            status: "in-progress"
          }
        )
        (ok enrollment-id)
      )
      ERR-INVALID-TRAINING
    )
  )
)

(define-public (complete-training (enrollment-id uint))
  (let
    (
      (enrollment (map-get? training-enrollment { enrollment-id: enrollment-id }))
    )
    (match enrollment
      enroll-data
      (begin
        (asserts! (is-eq tx-sender (get principal-addr enroll-data)) ERR-UNAUTHORIZED)
        (map-set training-enrollment
          { enrollment-id: enrollment-id }
          (merge enroll-data
            {
              completion-date: (some burn-block-height),
              status: "completed"
            }
          )
        )
        (ok true)
      )
      ERR-INVALID-TRAINING
    )
  )
)

(define-public (update-compliance-score (organization-id uint) (new-score uint))
  (let
    (
      (current (map-get? compliance-status { organization-id: organization-id }))
    )
    (match current
      org-data
      (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (and (>= new-score u0) (<= new-score u100)) ERR-INVALID-AUDIT)
        (map-set compliance-status
          { organization-id: organization-id }
          (merge org-data { compliance-score: new-score })
        )
        (ok true)
      )
      ERR-INVALID-REGULATION
    )
  )
)

(define-read-only (get-regulation (regulation-id uint))
  (map-get? regulations { regulation-id: regulation-id })
)

(define-read-only (get-compliance-status (organization-id uint))
  (map-get? compliance-status { organization-id: organization-id })
)

(define-read-only (get-audit-record (audit-id uint))
  (map-get? audit-records { audit-id: audit-id })
)

(define-read-only (get-training-module (training-id uint))
  (map-get? training-modules { training-id: training-id })
)

(define-read-only (get-enrollment-status (enrollment-id uint))
  (map-get? training-enrollment { enrollment-id: enrollment-id })
)

(define-read-only (get-total-violations)
  (var-get total-violations)
)

(define-read-only (is-compliant (organization-id uint))
  (let
    (
      (status (map-get? compliance-status { organization-id: organization-id }))
    )
    (match status
      org-data
      (>= (get compliance-score org-data) COMPLIANCE-THRESHOLD)
      false
    )
  )
)

