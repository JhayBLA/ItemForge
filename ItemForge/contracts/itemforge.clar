;; ItemForge: On-Chain Game Item Registry
;; Enables:
;; 1. Game masters to mint and register unique in-game items
;; 2. Players to claim, trade, and lock items
;; 3. Auditors to verify item authenticity
;; 4. Automated royalty splits for item creators

(define-constant game-authority tx-sender)

;; Error codes
(define-constant err-not-authorized (err u600))
(define-constant err-item-exists (err u601))
(define-constant err-item-unknown (err u602))
(define-constant err-item-locked (err u603))
(define-constant err-item-unlocked (err u604))
(define-constant err-trait-invalid (err u605))
(define-constant err-not-auditor (err u606))
(define-constant err-not-game-master (err u607))
(define-constant err-already-claimed (err u608))
(define-constant err-invalid-equip-window (err u609))
(define-constant err-invalid-item-hash (err u610))
(define-constant err-authority-access (err u611))
(define-constant err-claiming-closed (err u612))
(define-constant err-empty-item-id (err u613))
(define-constant err-empty-trait-data (err u614))
(define-constant err-empty-item-class (err u615))

;; Item registry
(define-map items
  { item-number: uint }
  {
    game-master: principal,
    item-identifier: (string-ascii 64),
    trait-data: (string-ascii 256),
    item-class: (string-ascii 256),
    mint-block: uint,
    equip-window: uint,
    rarity-hash: uint,
    highest-bid: uint,
    lead-claimant: (optional principal),
    claiming-open: bool,
    retired: bool
  }
)

(define-map player-claims
  { item-number: uint, player: principal }
  { bid-amount: uint, claim-block: uint }
)

;; Item counter
(define-data-var item-sequence uint u1)

;; Royalty rate (1% = 100 basis points)
(define-data-var royalty-rate-bps uint u100)

;; Queries

(define-read-only (get-item (item-number uint))
  (map-get? items { item-number: item-number })
)

(define-read-only (get-player-claim (item-number uint) (player principal))
  (map-get? player-claims { item-number: item-number, player: player })
)

(define-read-only (item-exists (item-number uint))
  (is-some (get-item item-number))
)

(define-read-only (is-claiming-open (item-number uint))
  (match (get-item item-number)
    item-info (and
                (get claiming-open item-info)
                (< block-height (get equip-window item-info))
              )
    false
  )
)

(define-read-only (is-item-retired (item-number uint))
  (match (get-item item-number)
    item-info (>= block-height (get equip-window item-info))
    false
  )
)

(define-read-only (get-next-item-number)
  (var-get item-sequence)
)

(define-read-only (get-royalty-rate-bps)
  (var-get royalty-rate-bps)
)

(define-read-only (calculate-royalty (value uint))
  (/ (* value (var-get royalty-rate-bps)) u10000)
)

;; Helpers

(define-private (calculate-creator-share (value uint))
  (- value (calculate-royalty value))
)

(define-private (validate-item-id (item-id (string-ascii 64)))
  (> (len item-id) u0)
)

(define-private (validate-trait-data (traits (string-ascii 256)))
  (> (len traits) u0)
)

(define-private (validate-item-class (class (string-ascii 256)))
  (> (len class) u0)
)

;; Core operations

(define-public (mint-item
                (item-identifier (string-ascii 64))
                (trait-data (string-ascii 256))
                (item-class (string-ascii 256))
                (equip-period uint)
                (rarity-hash uint))
  (let ((item-number (var-get item-sequence))
        (mint-block block-height)
        (equip-window (+ block-height equip-period)))
    (begin
      (asserts! (validate-item-id item-identifier) err-empty-item-id)
      (asserts! (validate-trait-data trait-data) err-empty-trait-data)
      (asserts! (validate-item-class item-class) err-empty-item-class)
      (asserts! (> equip-period u0) err-invalid-equip-window)
      (asserts! (> rarity-hash u0) err-invalid-item-hash)

      (map-set items
        { item-number: item-number }
        {
          game-master: tx-sender,
          item-identifier: item-identifier,
          trait-data: trait-data,
          item-class: item-class,
          mint-block: mint-block,
          equip-window: equip-window,
          rarity-hash: rarity-hash,
          highest-bid: u0,
          lead-claimant: none,
          claiming-open: true,
          retired: false
        }
      )

      (var-set item-sequence (+ item-number u1))

      (ok item-number)
    )
  )
)

(define-public (claim-item (item-number uint) (bid-amount uint))
  (let ((item-info (unwrap! (get-item item-number) err-item-unknown)))
    (begin
      (asserts! (get claiming-open item-info) err-claiming-closed)
      (asserts! (< block-height (get equip-window item-info)) err-item-locked)

      (asserts! (if (is-some (get lead-claimant item-info))
                   (> bid-amount (get highest-bid item-info))
                   (>= bid-amount (get rarity-hash item-info)))
               err-trait-invalid)

      (map-set player-claims
        { item-number: item-number, player: tx-sender }
        { bid-amount: bid-amount, claim-block: block-height }
      )

      (map-set items
        { item-number: item-number }
        (merge item-info {
          highest-bid: bid-amount,
          lead-claimant: (some tx-sender)
        })
      )

      (ok true)
    )
  )
)

(define-public (lock-item (item-number uint))
  (let ((item-info (unwrap! (get-item item-number) err-item-unknown)))
    (begin
      (asserts! (is-eq tx-sender (get game-master item-info)) err-not-game-master)
      (asserts! (get claiming-open item-info) err-claiming-closed)
      (asserts! (< block-height (get equip-window item-info)) err-item-locked)

      (map-set items
        { item-number: item-number }
        (merge item-info {
          claiming-open: false,
          equip-window: block-height
        })
      )

      (ok true)
    )
  )
)

(define-public (retire-item (item-number uint))
  (let ((item-info (unwrap! (get-item item-number) err-item-unknown)))
    (begin
      (asserts! (is-eq tx-sender (get game-master item-info)) err-not-game-master)
      (asserts! (get claiming-open item-info) err-claiming-closed)
      (asserts! (is-eq (get highest-bid item-info) u0) err-trait-invalid)

      (map-set items
        { item-number: item-number }
        (merge item-info { claiming-open: false })
      )

      (ok true)
    )
  )
)

;; Game governance

(define-public (update-royalty-rate (new-rate-bps uint))
  (begin
    (asserts! (is-eq tx-sender game-authority) err-authority-access)
    (asserts! (<= new-rate-bps u1000) err-not-authorized)
    (ok (var-set royalty-rate-bps new-rate-bps))
  )
)