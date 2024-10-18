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
