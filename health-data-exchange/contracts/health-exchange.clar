;; Healthcare Data Exchange Platform Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-tokens (err u103))
(define-constant err-already-contributed (err u104))
(define-constant err-data-exists (err u105))
(define-constant err-invalid-request (err u106))

;; Data Variables
(define-map patient-data { patient: principal } 
  { data-hash: (buff 32), 
  is-shared: bool, 
  consent-timestamp: uint,
  data-type: (string-ascii 50),
  sensitivity-level: uint  
  })


(define-map access-permissions { patient: principal, provider: principal } { can-access: bool, access-timestamp: uint  })
(define-map research-contributions { patient: principal, researcher: principal } { contribution-count: uint, last-contribution-timestamp: uint })

(define-map access-logs { 
  patient: principal, 
  provider: principal, 
  access-timestamp: uint 
} { 
  accessed-fields: (list 10 (string-ascii 50)),
  access-purpose: (string-ascii 100)
})

(define-map research-proposals {
  researcher: principal,
  proposal-id: uint
} {
  research-title: (string-ascii 100),
  description: (string-ascii 500),
  required-fields: (list 10 (string-ascii 50)),
  approved: bool,
  funding-requested: uint
})

(define-map patient-consent-preferences { 
  patient: principal 
} { 
  allow-anonymous-research: bool,
  allow-identifiable-research: bool,
  notify-on-access: bool
})

(define-map provider-credentials {
  provider: principal
} {
  institution: (string-ascii 100),
  credential-hash: (buff 32),
  verification-status: bool
})

;; Fungible Token
(define-fungible-token data-token u1000000000)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner))

(define-private (mint-research-tokens (amount uint))
  (ft-mint? data-token amount tx-sender))

;; Public Functions

;; Store patient data
;; Advanced Data Storage with Metadata
(define-public (store-advanced-data 
  (data-hash (buff 32))
  (data-type (string-ascii 50))
  (sensitivity-level uint)
)
  (begin
    ;; Check if data already exists
    (asserts! (is-none (map-get? patient-data { patient: tx-sender })) (err err-data-exists))
    
    ;; Store data with additional metadata
    (ok (map-set patient-data 
      { patient: tx-sender } 
      { 
        data-hash: data-hash, 
        is-shared: false, 
        consent-timestamp: block-height,
        data-type: data-type,
        sensitivity-level: sensitivity-level
      }))))


;; Grant access to a healthcare provider
(define-public (grant-access (provider principal))
  (ok (map-set access-permissions { patient: tx-sender, provider: provider } { can-access: true,  access-timestamp: block-height  })))

;; Revoke access from a healthcare provider
(define-public (revoke-access (provider principal))
  (ok (map-set access-permissions { patient: tx-sender, provider: provider } { can-access: false,  access-timestamp: block-height  })))

;; Check if a provider has access to a patient's data
(define-read-only (check-access (patient principal) (provider principal))
  (default-to false (get can-access (map-get? access-permissions { patient: patient, provider: provider }))))

;; Share data with researchers
(define-public (share-with-researchers)
  (let ((current-data (unwrap! (map-get? patient-data { patient: tx-sender }) (err err-not-found))))
    (begin
      (map-set patient-data { 
        patient: tx-sender } 
        { data-hash: (get data-hash (unwrap-panic (map-get? patient-data { patient: tx-sender }))),
        is-shared: true,
          consent-timestamp: (get consent-timestamp current-data),
          data-type: (get data-type current-data),
          sensitivity-level: (get sensitivity-level current-data)})
      (ok true))))

;; Get patient data hash
(define-read-only (get-patient-data (patient principal))
  (match (map-get? patient-data { patient: patient })
    data-info (ok (get data-hash data-info))
    (err err-not-found)))

  ;; Update patient data
(define-public (update-data (new-data-hash (buff 32)))
  (let ((current-data (unwrap! (map-get? patient-data { patient: tx-sender }) (err err-not-found))))
    (ok (map-set patient-data 
      { patient: tx-sender } 
      { 
        data-hash: new-data-hash, 
        is-shared: (get is-shared current-data), 
        consent-timestamp: block-height,
        data-type: (get data-type current-data),
        sensitivity-level: (get sensitivity-level current-data) 
      }))))

;; Record research contribution
(define-public (record-research-contribution (researcher principal))
  (let ((current-contribution (default-to { contribution-count: u0, last-contribution-timestamp: u0 } 
                                (map-get? research-contributions { patient: tx-sender, researcher: researcher }))))
    (begin
      (map-set research-contributions 
        { patient: tx-sender, researcher: researcher }
        { 
          contribution-count: (+ (get contribution-count current-contribution) u1),
          last-contribution-timestamp: block-height 
        })
      
      ;; Mint additional tokens for repeat contributions
      (if (> (get contribution-count current-contribution) u0)
          (try! (mint-research-tokens u5))
          (try! (mint-research-tokens u10)))
      (ok true))))

;; Owner-only function to withdraw tokens
(define-public (withdraw-tokens (amount uint))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (ft-transfer? data-token amount contract-owner tx-sender)))


;; Submit Research Proposal
(define-public (submit-research-proposal
  (proposal-id uint)
  (research-title (string-ascii 100))
  (description (string-ascii 500))
  (required-fields (list 10 (string-ascii 50)))
  (funding-requested uint)
)
  (begin
    (map-set research-proposals 
      { researcher: tx-sender, proposal-id: proposal-id }
      {
        research-title: research-title,
        description: description,
        required-fields: required-fields,
        approved: false,
        funding-requested: funding-requested
      })
    (ok true)))

;; Approve Research Proposal (Owner Only)
(define-public (approve-research-proposal (researcher principal) (proposal-id uint))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (map-set research-proposals 
      { researcher: researcher, proposal-id: proposal-id }
      (merge 
        (unwrap-panic (map-get? research-proposals { researcher: researcher, proposal-id: proposal-id }))
        { approved: true }))
    (ok true)))

;; Log Detailed Access
(define-public (log-data-access 
  (patient principal)
  (provider principal)
  (accessed-fields (list 10 (string-ascii 50)))
  (access-purpose (string-ascii 100))
)
  (begin
    (map-set access-logs 
      { 
        patient: patient, 
        provider: provider, 
        access-timestamp: block-height 
      }
      {
        accessed-fields: accessed-fields,
        access-purpose: access-purpose
      })
    (ok true)))

;; Set Patient Consent Preferences
(define-public (set-consent-preferences
  (allow-anonymous-research bool)
  (allow-identifiable-research bool)
  (notify-on-access bool)
)
  (begin
    (map-set patient-consent-preferences 
      { patient: tx-sender }
      {
        allow-anonymous-research: allow-anonymous-research,
        allow-identifiable-research: allow-identifiable-research,
        notify-on-access: notify-on-access
      })
    (ok true)))