;; Healthcare Data Exchange Platform Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-tokens (err u103))
(define-constant err-already-contributed (err u104))

;; Data Variables
(define-map patient-data { patient: principal } { data-hash: (buff 32), is-shared: bool, consent-timestamp: uint  })
(define-map access-permissions { patient: principal, provider: principal } { can-access: bool, access-timestamp: uint  })
(define-map research-contributions { patient: principal, researcher: principal } { contribution-count: uint, last-contribution-timestamp: uint })

;; Fungible Token
(define-fungible-token data-token u1000000000)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner))

(define-private (mint-research-tokens (amount uint))
  (ft-mint? data-token amount tx-sender))

;; Public Functions

;; Store patient data
(define-public (store-data (data-hash (buff 32)))
  (ok (map-set patient-data { patient: tx-sender } { data-hash: data-hash, is-shared: false,  consent-timestamp: block-height  })))

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
          consent-timestamp: (get consent-timestamp current-data)  })
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
        consent-timestamp: block-height 
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



