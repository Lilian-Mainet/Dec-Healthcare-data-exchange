;; Healthcare Data Exchange Platform Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))

;; Data Variables
(define-map patient-data { patient: principal } { data-hash: (buff 32), is-shared: bool })
(define-map access-permissions { patient: principal, provider: principal } { can-access: bool })
(define-map research-contributions { patient: principal, researcher: principal } { contribution-count: uint })

;; Fungible Token
(define-fungible-token data-token u1000000000)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner))


;; Public Functions

;; Store patient data
(define-public (store-data (data-hash (buff 32)))
  (ok (map-set patient-data { patient: tx-sender } { data-hash: data-hash, is-shared: false })))

;; Grant access to a healthcare provider
(define-public (grant-access (provider principal))
  (ok (map-set access-permissions { patient: tx-sender, provider: provider } { can-access: true })))

;; Revoke access from a healthcare provider
(define-public (revoke-access (provider principal))
  (ok (map-set access-permissions { patient: tx-sender, provider: provider } { can-access: false })))

;; Check if a provider has access to a patient's data
(define-read-only (check-access (patient principal) (provider principal))
  (default-to false (get can-access (map-get? access-permissions { patient: patient, provider: provider }))))

;; Share data with researchers
(define-public (share-with-researchers)
  (begin
    (map-set patient-data { patient: tx-sender } { data-hash: (get data-hash (unwrap-panic (map-get? patient-data { patient: tx-sender }))), is-shared: true })
    (ok true)))

;; Get patient data hash
(define-read-only (get-patient-data (patient principal))
  (match (map-get? patient-data { patient: patient })
    data-info (ok (get data-hash data-info))
    (err err-not-found)))

