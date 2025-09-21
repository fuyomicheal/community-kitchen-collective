;; Community Kitchen Collective - Health Compliance Contract
;; Ensure food safety and health code compliance for all users

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-already-exists (err u202))
(define-constant err-expired-certification (err u203))
(define-constant err-insufficient-score (err u204))
(define-constant err-unauthorized (err u205))
(define-constant err-invalid-input (err u206))
(define-constant err-training-incomplete (err u207))
(define-constant err-violation-exists (err u208))

;; Compliance requirements
(define-constant min-compliance-score u75)
(define-constant cert-validity-days u365) ;; 1 year
(define-constant training-required-hours u8)
(define-constant max-violations-allowed u3)

;; Data Variables
(define-data-var next-certification-id uint u1)
(define-data-var next-inspection-id uint u1)
(define-data-var next-violation-id uint u1)
(define-data-var next-training-id uint u1)

;; Data Maps for Certifications
(define-map user-certifications
  { user-principal: principal }
  {
    food-handler-cert: bool,
    food-safety-cert: bool,
    allergen-training: bool,
    haccp-certified: bool,
    certification-date: uint,
    expiry-date: uint,
    issuing-authority: (string-ascii 100),
    certification-number: (string-ascii 50),
    compliance-score: uint,
    last-updated: uint,
    active-status: bool
  }
)

(define-map certification-records
  { cert-id: uint }
  {
    user-principal: principal,
    certification-type: (string-ascii 30), ;; "food-handler", "food-safety", "allergen", "haccp"
    issue-date: uint,
    expiry-date: uint,
    issuing-body: (string-ascii 100),
    certificate-number: (string-ascii 50),
    verified: bool,
    verification-date: (optional uint),
    document-hash: (optional (buff 32))
  }
)

;; Health Inspection Records
(define-map inspection-records
  { inspection-id: uint }
  {
    kitchen-id: uint,
    inspector-name: (string-ascii 50),
    inspection-date: uint,
    inspection-type: (string-ascii 30), ;; "routine", "complaint", "follow-up", "licensing"
    overall-score: uint, ;; Out of 100
    temperature-control: uint,
    cleanliness: uint,
    food-storage: uint,
    equipment-condition: uint,
    documentation: uint,
    passed: bool,
    notes: (string-ascii 500),
    follow-up-required: bool,
    follow-up-date: (optional uint)
  }
)

;; Violation Tracking
(define-map health-violations
  { violation-id: uint }
  {
    user-principal: principal,
    kitchen-id: uint,
    violation-type: (string-ascii 50), ;; "temperature", "cleanliness", "storage", "documentation"
    severity: (string-ascii 20), ;; "minor", "major", "critical"
    description: (string-ascii 200),
    discovered-date: uint,
    resolved: bool,
    resolution-date: (optional uint),
    resolution-notes: (optional (string-ascii 300)),
    penalty-points: uint,
    inspector-name: (string-ascii 50)
  }
)

;; Training Records
(define-map training-records
  { training-id: uint }
  {
    user-principal: principal,
    training-type: (string-ascii 50), ;; "food-safety", "allergen", "haccp", "cleaning"
    completion-date: uint,
    training-provider: (string-ascii 100),
    hours-completed: uint,
    score-achieved: uint,
    certificate-issued: bool,
    renewal-due: uint,
    training-materials: (optional (string-ascii 200))
  }
)

;; User Compliance Status
(define-map user-compliance
  { user-principal: principal }
  {
    current-score: uint,
    total-violations: uint,
    resolved-violations: uint,
    pending-violations: uint,
    last-inspection: (optional uint),
    next-required-training: (optional uint),
    compliance-status: (string-ascii 20), ;; "compliant", "warning", "non-compliant", "suspended"
    status-updated: uint,
    restriction-level: uint ;; 0 = no restrictions, 1-5 = increasing restrictions
  }
)

;; Kitchen Health Status
(define-map kitchen-health-status
  { kitchen-id: uint }
  {
    last-inspection-date: uint,
    last-inspection-score: uint,
    current-violations: uint,
    health-permit-status: bool,
    permit-expiry: uint,
    maintenance-required: bool,
    operational-status: (string-ascii 20), ;; "approved", "conditional", "closed"
    next-inspection-due: uint
  }
)

;; Public Functions

;; Register or update user food safety certification
(define-public (register-food-certification 
    (cert-type (string-ascii 30)) 
    (issuing-body (string-ascii 100)) 
    (cert-number (string-ascii 50)) 
    (expiry-date uint))
  (let
    (
      (cert-id (var-get next-certification-id))
      (current-time u1640995200) ;; Mock timestamp
      (cert-record (map-get? user-certifications {user-principal: tx-sender}))
    )
    (asserts! (or (is-eq cert-type "food-handler") 
                  (or (is-eq cert-type "food-safety")
                      (or (is-eq cert-type "allergen")
                          (is-eq cert-type "haccp")))) err-invalid-input)
    (asserts! (> expiry-date current-time) err-invalid-input)
    
    ;; Create certification record
    (map-set certification-records
      {cert-id: cert-id}
      {
        user-principal: tx-sender,
        certification-type: cert-type,
        issue-date: current-time,
        expiry-date: expiry-date,
        issuing-body: issuing-body,
        certificate-number: cert-number,
        verified: false, ;; Requires verification
        verification-date: none,
        document-hash: none
      }
    )
    
    ;; Update or create user certification status
    (match cert-record
      existing-cert (map-set user-certifications
        {user-principal: tx-sender}
        (merge existing-cert {
          food-handler-cert: (if (is-eq cert-type "food-handler") true (get food-handler-cert existing-cert)),
          food-safety-cert: (if (is-eq cert-type "food-safety") true (get food-safety-cert existing-cert)),
          allergen-training: (if (is-eq cert-type "allergen") true (get allergen-training existing-cert)),
          haccp-certified: (if (is-eq cert-type "haccp") true (get haccp-certified existing-cert)),
          certification-date: current-time,
          expiry-date: expiry-date,
          last-updated: current-time
        })
      )
      ;; Create new certification record
      (map-set user-certifications
        {user-principal: tx-sender}
        {
          food-handler-cert: (is-eq cert-type "food-handler"),
          food-safety-cert: (is-eq cert-type "food-safety"),
          allergen-training: (is-eq cert-type "allergen"),
          haccp-certified: (is-eq cert-type "haccp"),
          certification-date: current-time,
          expiry-date: expiry-date,
          issuing-authority: issuing-body,
          certification-number: cert-number,
          compliance-score: u100, ;; Start with perfect score
          last-updated: current-time,
          active-status: true
        }
      )
    )
    
    ;; Update compliance status
    (unwrap-panic (update-user-compliance-score tx-sender))
    
    ;; Increment certification ID
    (var-set next-certification-id (+ cert-id u1))
    
    (ok cert-id)
  )
)

;; Record health inspection results
(define-public (record-health-inspection 
    (kitchen-id uint)
    (inspector-name (string-ascii 50))
    (inspection-type (string-ascii 30))
    (temp-score uint) (clean-score uint) (storage-score uint) 
    (equipment-score uint) (doc-score uint)
    (notes (string-ascii 500)))
  (let
    (
      (inspection-id (var-get next-inspection-id))
      (current-time u1640995200)
      (overall-score (/ (+ temp-score clean-score storage-score equipment-score doc-score) u5))
      (inspection-passed (>= overall-score u70)) ;; 70% passing grade
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (<= temp-score u100) (<= clean-score u100) (<= storage-score u100) 
                   (<= equipment-score u100) (<= doc-score u100)) err-invalid-input)
    
    ;; Create inspection record
    (map-set inspection-records
      {inspection-id: inspection-id}
      {
        kitchen-id: kitchen-id,
        inspector-name: inspector-name,
        inspection-date: current-time,
        inspection-type: inspection-type,
        overall-score: overall-score,
        temperature-control: temp-score,
        cleanliness: clean-score,
        food-storage: storage-score,
        equipment-condition: equipment-score,
        documentation: doc-score,
        passed: inspection-passed,
        notes: notes,
        follow-up-required: (< overall-score u85),
        follow-up-date: (if (< overall-score u85) (some (+ current-time u2592000)) none) ;; 30 days
      }
    )
    
    ;; Update kitchen health status
    (map-set kitchen-health-status
      {kitchen-id: kitchen-id}
      {
        last-inspection-date: current-time,
        last-inspection-score: overall-score,
        current-violations: u0, ;; Will be updated separately
        health-permit-status: inspection-passed,
        permit-expiry: (+ current-time u31536000), ;; 1 year
        maintenance-required: (< equipment-score u80),
        operational-status: (if inspection-passed "approved" "conditional"),
        next-inspection-due: (+ current-time u15552000) ;; 6 months
      }
    )
    
    ;; Increment inspection ID
    (var-set next-inspection-id (+ inspection-id u1))
    
    (ok inspection-id)
  )
)

;; Report health code violation
(define-public (report-violation 
    (user-principal principal)
    (kitchen-id uint)
    (violation-type (string-ascii 50))
    (severity (string-ascii 20))
    (description (string-ascii 200)))
  (let
    (
      (violation-id (var-get next-violation-id))
      (current-time u1640995200)
      (penalty-points (if (is-eq severity "critical") u15
                          (if (is-eq severity "major") u10 u5)))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (or (is-eq severity "minor") 
                  (or (is-eq severity "major") 
                      (is-eq severity "critical"))) err-invalid-input)
    
    ;; Create violation record
    (map-set health-violations
      {violation-id: violation-id}
      {
        user-principal: user-principal,
        kitchen-id: kitchen-id,
        violation-type: violation-type,
        severity: severity,
        description: description,
        discovered-date: current-time,
        resolved: false,
        resolution-date: none,
        resolution-notes: none,
        penalty-points: penalty-points,
        inspector-name: "System"
      }
    )
    
    ;; Update user compliance status
    (unwrap-panic (add-violation-to-user user-principal penalty-points))
    
    ;; Increment violation ID
    (var-set next-violation-id (+ violation-id u1))
    
    (ok violation-id)
  )
)

;; Resolve health violation
(define-public (resolve-violation (violation-id uint) (resolution-notes (string-ascii 300)))
  (let
    (
      (violation (unwrap! (map-get? health-violations {violation-id: violation-id}) err-not-found))
      (current-time u1640995200)
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get resolved violation)) err-invalid-input)
    
    ;; Update violation as resolved
    (map-set health-violations
      {violation-id: violation-id}
      (merge violation {
        resolved: true,
        resolution-date: (some current-time),
        resolution-notes: (some resolution-notes)
      })
    )
    
    ;; Update user compliance
    (unwrap-panic (resolve-user-violation (get user-principal violation)))
    
    (ok true)
  )
)

;; Complete mandatory training
(define-public (complete-training 
    (training-type (string-ascii 50))
    (provider (string-ascii 100))
    (hours uint)
    (score uint))
  (let
    (
      (training-id (var-get next-training-id))
      (current-time u1640995200)
      (renewal-due (+ current-time u31536000)) ;; 1 year
      (cert-issued (>= score u80)) ;; 80% required for certificate
    )
    (asserts! (<= hours u40) err-invalid-input) ;; Max 40 hours
    (asserts! (<= score u100) err-invalid-input)
    
    ;; Create training record
    (map-set training-records
      {training-id: training-id}
      {
        user-principal: tx-sender,
        training-type: training-type,
        completion-date: current-time,
        training-provider: provider,
        hours-completed: hours,
        score-achieved: score,
        certificate-issued: cert-issued,
        renewal-due: renewal-due,
        training-materials: none
      }
    )
    
    ;; Update user compliance score if training passed
    (if cert-issued
      (begin
        (unwrap-panic (update-user-compliance-score tx-sender))
        true
      )
      true
    )
    
    ;; Increment training ID
    (var-set next-training-id (+ training-id u1))
    
    (ok training-id)
  )
)

;; Check user compliance status
(define-public (check-user-compliance (user-principal principal))
  (let
    (
      (cert (map-get? user-certifications {user-principal: user-principal}))
      (compliance (map-get? user-compliance {user-principal: user-principal}))
      (current-time u1640995200)
    )
    (match cert
      user-cert
      (let
        (
          (cert-valid (> (get expiry-date user-cert) current-time))
          (score-adequate (>= (get compliance-score user-cert) min-compliance-score))
        )
        (match compliance
          comp-status
          (ok {
            compliant: (and cert-valid score-adequate 
                           (< (get pending-violations comp-status) max-violations-allowed)),
            certification-valid: cert-valid,
            compliance-score: (get current-score comp-status),
            violations: (get pending-violations comp-status),
            status: (get compliance-status comp-status)
          })
          (ok {
            compliant: (and cert-valid score-adequate),
            certification-valid: cert-valid,
            compliance-score: (get compliance-score user-cert),
            violations: u0,
            status: "compliant"
          })
        )
      )
      (ok {
        compliant: false,
        certification-valid: false,
        compliance-score: u0,
        violations: u0,
        status: "no-certification"
      })
    )
  )
)

;; Private Helper Functions

(define-private (update-user-compliance-score (user-principal principal))
  (let
    (
      (cert (map-get? user-certifications {user-principal: user-principal}))
      (compliance (map-get? user-compliance {user-principal: user-principal}))
      (current-time u1640995200)
    )
    (match cert
      user-cert
      (let
        (
          ;; Calculate new score based on certifications and violations
          (base-score u100)
          (cert-bonus (+ (if (get food-handler-cert user-cert) u5 u0)
                        (+ (if (get food-safety-cert user-cert) u5 u0)
                           (+ (if (get allergen-training user-cert) u3 u0)
                              (if (get haccp-certified user-cert) u7 u0)))))
          (violation-penalty (match compliance
            comp (get pending-violations comp)
            u0
          ))
          (new-score (if (> (+ base-score cert-bonus) (* violation-penalty u5))
                        (- (+ base-score cert-bonus) (* violation-penalty u5))
                        u0))
        )
        ;; Update certification record
        (map-set user-certifications
          {user-principal: user-principal}
          (merge user-cert {
            compliance-score: new-score,
            last-updated: current-time
          })
        )
        
        ;; Update or create compliance record
        (match compliance
          existing-comp (map-set user-compliance
            {user-principal: user-principal}
            (merge existing-comp {
              current-score: new-score,
              compliance-status: (if (>= new-score min-compliance-score) "compliant" "warning"),
              status-updated: current-time
            })
          )
          (map-set user-compliance
            {user-principal: user-principal}
            {
              current-score: new-score,
              total-violations: u0,
              resolved-violations: u0,
              pending-violations: u0,
              last-inspection: none,
              next-required-training: none,
              compliance-status: "compliant",
              status-updated: current-time,
              restriction-level: u0
            }
          )
        )
        (ok true)
      )
      (err err-not-found)
    )
  )
)

(define-private (add-violation-to-user (user-principal principal) (penalty-points uint))
  (let
    (
      (compliance (map-get? user-compliance {user-principal: user-principal}))
      (current-time u1640995200)
    )
    (match compliance
      existing-comp
      (let
        (
          (new-pending (+ (get pending-violations existing-comp) u1))
          (new-total (+ (get total-violations existing-comp) u1))
          (new-score (if (> (get current-score existing-comp) penalty-points)
                        (- (get current-score existing-comp) penalty-points)
                        u0))
          (new-status (if (>= new-pending max-violations-allowed) "non-compliant"
                         (if (< new-score min-compliance-score) "warning" "compliant")))
        )
        (map-set user-compliance
          {user-principal: user-principal}
          (merge existing-comp {
            current-score: new-score,
            total-violations: new-total,
            pending-violations: new-pending,
            compliance-status: new-status,
            status-updated: current-time,
            restriction-level: (if (>= new-pending max-violations-allowed) u3 
                                  (if (< new-score min-compliance-score) u1 u0))
          })
        )
      )
      ;; Create new compliance record if none exists
      (map-set user-compliance
        {user-principal: user-principal}
        {
          current-score: (- u100 penalty-points),
          total-violations: u1,
          resolved-violations: u0,
          pending-violations: u1,
          last-inspection: none,
          next-required-training: none,
          compliance-status: (if (< (- u100 penalty-points) min-compliance-score) "warning" "compliant"),
          status-updated: current-time,
          restriction-level: u0
        }
      )
    )
    (ok true)
  )
)

(define-private (resolve-user-violation (user-principal principal))
  (let
    (
      (compliance (unwrap! (map-get? user-compliance {user-principal: user-principal}) (err err-not-found)))
      (current-time u1640995200)
    )
    (let
      (
        (new-pending (if (> (get pending-violations compliance) u0)
                        (- (get pending-violations compliance) u1)
                        u0))
        (new-resolved (+ (get resolved-violations compliance) u1))
        (improved-score (+ (get current-score compliance) u5)) ;; Small bonus for resolution
        (new-status (if (< new-pending max-violations-allowed) 
                       (if (>= improved-score min-compliance-score) "compliant" "warning")
                       "non-compliant"))
      )
      (map-set user-compliance
        {user-principal: user-principal}
        (merge compliance {
          current-score: (if (<= improved-score u100) improved-score u100),
          resolved-violations: new-resolved,
          pending-violations: new-pending,
          compliance-status: new-status,
          status-updated: current-time,
          restriction-level: (if (< new-pending max-violations-allowed) u0 u2)
        })
      )
    )
    (ok true)
  )
)

;; Read-only Functions

(define-read-only (get-user-certifications (user-principal principal))
  (map-get? user-certifications {user-principal: user-principal})
)

(define-read-only (get-certification-record (cert-id uint))
  (map-get? certification-records {cert-id: cert-id})
)

(define-read-only (get-inspection-record (inspection-id uint))
  (map-get? inspection-records {inspection-id: inspection-id})
)

(define-read-only (get-violation-record (violation-id uint))
  (map-get? health-violations {violation-id: violation-id})
)

(define-read-only (get-training-record (training-id uint))
  (map-get? training-records {training-id: training-id})
)

(define-read-only (get-user-compliance-status (user-principal principal))
  (map-get? user-compliance {user-principal: user-principal})
)

(define-read-only (get-kitchen-health-status (kitchen-id uint))
  (map-get? kitchen-health-status {kitchen-id: kitchen-id})
)

(define-read-only (get-compliance-stats)
  {
    total-certifications: (- (var-get next-certification-id) u1),
    total-inspections: (- (var-get next-inspection-id) u1),
    total-violations: (- (var-get next-violation-id) u1),
    total-trainings: (- (var-get next-training-id) u1),
    min-compliance-score: min-compliance-score,
    max-violations-allowed: max-violations-allowed,
    training-required-hours: training-required-hours
  }
)

(define-read-only (is-user-compliant (user-principal principal))
  (let
    (
      (cert (map-get? user-certifications {user-principal: user-principal}))
      (compliance (map-get? user-compliance {user-principal: user-principal}))
      (current-time u1640995200)
    )
    (match cert
      user-cert
      (and 
        (get active-status user-cert)
        (> (get expiry-date user-cert) current-time)
        (>= (get compliance-score user-cert) min-compliance-score)
        (match compliance
          comp (< (get pending-violations comp) max-violations-allowed)
          true
        )
      )
      false
    )
  )
)

