;; Certification Tracking Contract
;; Monitors industry standard compliance and certification status

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-CERT-NOT-FOUND (err u401))
(define-constant ERR-INVALID-INPUT (err u402))
(define-constant ERR-CERT-EXPIRED (err u403))
(define-constant ERR-INVALID-STATUS (err u404))

;; Data Variables
(define-data-var next-cert-id uint u1)

;; Data Maps
(define-map certifications
  { cert-id: uint }
  {
    material-id: uint,
    standard-name: (string-ascii 50),
    cert-authority: principal,
    issued-at: uint,
    expires-at: uint,
    status: (string-ascii 20),
    cert-number: (string-ascii 50)
  }
)

(define-map certification-requirements
  { standard-name: (string-ascii 50) }
  {
    required-tests: (list 10 (string-ascii 50)),
    min-test-count: uint,
    validity-period-blocks: uint,
    renewal-required: bool
  }
)

(define-map certification-authorities
  { authority: principal }
  {
    name: (string-ascii 100),
    accreditation: (string-ascii 100),
    authorized-standards: (list 20 (string-ascii 50)),
    authorized-at: uint,
    is-active: bool
  }
)

(define-map test-compliance
  { cert-id: uint, test-name: (string-ascii 50) }
  {
    specimen-id: uint,
    result-value: (string-ascii 100),
    pass-criteria: (string-ascii 100),
    passed: bool,
    tested-at: uint
  }
)

;; Authorization check
(define-private (is-authorized (user principal))
  (or
    (is-eq user CONTRACT-OWNER)
    (is-eq user tx-sender)
  )
)

(define-private (is-cert-authority (authority principal))
  (match (map-get? certification-authorities { authority: authority })
    auth-data (get is-active auth-data)
    false
  )
)

(define-private (is-valid-cert-status (status (string-ascii 20)))
  (or
    (is-eq status "pending")
    (is-eq status "issued")
    (is-eq status "expired")
    (is-eq status "revoked")
    (is-eq status "suspended")
  )
)

;; Public Functions
(define-public (register-certification-authority
  (authority principal)
  (name (string-ascii 100))
  (accreditation (string-ascii 100))
  (authorized-standards (list 20 (string-ascii 50))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len authorized-standards) u0) ERR-INVALID-INPUT)

    (map-set certification-authorities
      { authority: authority }
      {
        name: name,
        accreditation: accreditation,
        authorized-standards: authorized-standards,
        authorized-at: block-height,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (set-certification-requirements
  (standard-name (string-ascii 50))
  (required-tests (list 10 (string-ascii 50)))
  (min-test-count uint)
  (validity-period-blocks uint)
  (renewal-required bool))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len standard-name) u0) ERR-INVALID-INPUT)
    (asserts! (> min-test-count u0) ERR-INVALID-INPUT)
    (asserts! (> validity-period-blocks u0) ERR-INVALID-INPUT)

    (map-set certification-requirements
      { standard-name: standard-name }
      {
        required-tests: required-tests,
        min-test-count: min-test-count,
        validity-period-blocks: validity-period-blocks,
        renewal-required: renewal-required
      }
    )
    (ok true)
  )
)

(define-public (issue-certification
  (material-id uint)
  (standard-name (string-ascii 50))
  (cert-number (string-ascii 50))
  (validity-period-blocks uint))
  (let ((cert-id (var-get next-cert-id)))
    (asserts! (is-cert-authority tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> material-id u0) ERR-INVALID-INPUT)
    (asserts! (> (len standard-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len cert-number) u0) ERR-INVALID-INPUT)
    (asserts! (> validity-period-blocks u0) ERR-INVALID-INPUT)

    (map-set certifications
      { cert-id: cert-id }
      {
        material-id: material-id,
        standard-name: standard-name,
        cert-authority: tx-sender,
        issued-at: block-height,
        expires-at: (+ block-height validity-period-blocks),
        status: "issued",
        cert-number: cert-number
      }
    )

    (var-set next-cert-id (+ cert-id u1))
    (ok cert-id)
  )
)

(define-public (record-test-compliance
  (cert-id uint)
  (test-name (string-ascii 50))
  (specimen-id uint)
  (result-value (string-ascii 100))
  (pass-criteria (string-ascii 100))
  (passed bool))
  (let ((cert (map-get? certifications { cert-id: cert-id })))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-some cert) ERR-CERT-NOT-FOUND)
    (asserts! (> (len test-name) u0) ERR-INVALID-INPUT)
    (asserts! (> specimen-id u0) ERR-INVALID-INPUT)

    (map-set test-compliance
      { cert-id: cert-id, test-name: test-name }
      {
        specimen-id: specimen-id,
        result-value: result-value,
        pass-criteria: pass-criteria,
        passed: passed,
        tested-at: block-height
      }
    )
    (ok true)
  )
)

(define-public (update-certification-status
  (cert-id uint)
  (new-status (string-ascii 20)))
  (let ((cert (map-get? certifications { cert-id: cert-id })))
    (asserts! (is-cert-authority tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-some cert) ERR-CERT-NOT-FOUND)
    (asserts! (is-valid-cert-status new-status) ERR-INVALID-STATUS)

    (map-set certifications
      { cert-id: cert-id }
      (merge (unwrap-panic cert) { status: new-status })
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-certification (cert-id uint))
  (map-get? certifications { cert-id: cert-id })
)

(define-read-only (get-certification-requirements (standard-name (string-ascii 50)))
  (map-get? certification-requirements { standard-name: standard-name })
)

(define-read-only (get-certification-authority (authority principal))
  (map-get? certification-authorities { authority: authority })
)

(define-read-only (get-test-compliance (cert-id uint) (test-name (string-ascii 50)))
  (map-get? test-compliance { cert-id: cert-id, test-name: test-name })
)

(define-read-only (is-certification-valid (cert-id uint))
  (match (map-get? certifications { cert-id: cert-id })
    cert (and
           (is-eq (get status cert) "issued")
           (< block-height (get expires-at cert))
         )
    false
  )
)
