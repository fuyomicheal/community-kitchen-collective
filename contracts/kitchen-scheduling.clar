;; Community Kitchen Collective - Kitchen Scheduling Contract
;; Schedule and manage access to shared kitchen facilities

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-time (err u103))
(define-constant err-time-conflict (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-booking-expired (err u106))
(define-constant err-insufficient-payment (err u107))
(define-constant err-cancellation-too-late (err u108))

;; Data Variables
(define-data-var next-user-id uint u1)
(define-data-var next-booking-id uint u1)
(define-data-var next-kitchen-id uint u1)
(define-data-var hourly-rate uint u50000000) ;; 0.05 STX per hour
(define-data-var cancellation-window uint u86400) ;; 24 hours in seconds
(define-data-var max-booking-hours uint u12) ;; Maximum 12 hours per booking

;; Data Maps
(define-map kitchen-users
  { user-id: uint }
  {
    principal: principal,
    name: (string-ascii 50),
    business-name: (optional (string-ascii 100)),
    contact-info: (string-ascii 100),
    membership-type: (string-ascii 20), ;; "individual", "business", "community"
    registration-date: uint,
    food-handler-cert: bool,
    active: bool,
    total-bookings: uint,
    total-hours-used: uint,
    compliance-score: uint,
    outstanding-balance: uint
  }
)

(define-map user-by-principal
  { principal: principal }
  { user-id: uint }
)

(define-map kitchen-spaces
  { kitchen-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    capacity: uint, ;; Maximum users at one time
    hourly-rate: uint,
    equipment-list: (list 20 (string-ascii 30)),
    active: bool,
    maintenance-mode: bool,
    total-bookings: uint,
    utilization-hours: uint
  }
)

(define-map bookings
  { booking-id: uint }
  {
    user-id: uint,
    kitchen-id: uint,
    start-time: uint,
    end-time: uint,
    duration-hours: uint,
    total-cost: uint,
    payment-status: (string-ascii 20), ;; "pending", "paid", "refunded"
    booking-status: (string-ascii 20), ;; "scheduled", "active", "completed", "cancelled", "no-show"
    purpose: (string-ascii 100),
    special-requirements: (optional (string-ascii 200)),
    access-code: (optional (string-ascii 10)),
    check-in-time: (optional uint),
    check-out-time: (optional uint),
    created-at: uint
  }
)

(define-map booking-conflicts
  { kitchen-id: uint, time-slot: uint }
  {
    active-bookings: (list 10 uint),
    current-capacity: uint,
    max-capacity: uint
  }
)

(define-map user-schedules
  { user-id: uint, date: uint }
  {
    scheduled-hours: uint,
    booking-ids: (list 5 uint),
    total-cost: uint,
    confirmed: bool
  }
)

(define-map kitchen-availability
  { kitchen-id: uint, hour-slot: uint }
  {
    available: bool,
    current-bookings: uint,
    max-capacity: uint,
    hourly-rate: uint,
    maintenance-scheduled: bool
  }
)

(define-map payment-records
  { payment-id: uint }
  {
    booking-id: uint,
    user-id: uint,
    amount: uint,
    payment-method: (string-ascii 20), ;; "stx", "credit", "membership"
    transaction-hash: (optional (buff 32)),
    payment-date: uint,
    refund-amount: uint,
    refund-date: (optional uint)
  }
)

;; Data Variables for ID tracking
(define-data-var next-payment-id uint u1)

;; Public Functions

;; Register new kitchen user
(define-public (register-kitchen-user (name (string-ascii 50)) (business-name (optional (string-ascii 100))) (contact-info (string-ascii 100)) (membership-type (string-ascii 20)))
  (let
    (
      (user-id (var-get next-user-id))
      (current-time u1000000)
    )
    (asserts! (is-none (map-get? user-by-principal {principal: tx-sender})) err-already-exists)
    (asserts! (or (is-eq membership-type "individual") 
                  (or (is-eq membership-type "business") 
                      (is-eq membership-type "community"))) err-invalid-time)
    
    ;; Create user record
    (map-set kitchen-users
      {user-id: user-id}
      {
        principal: tx-sender,
        name: name,
        business-name: business-name,
        contact-info: contact-info,
        membership-type: membership-type,
        registration-date: current-time,
        food-handler-cert: false, ;; Must be verified separately
        active: true,
        total-bookings: u0,
        total-hours-used: u0,
        compliance-score: u100, ;; Start with perfect score
        outstanding-balance: u0
      }
    )
    
    ;; Map principal to user ID
    (map-set user-by-principal
      {principal: tx-sender}
      {user-id: user-id}
    )
    
    ;; Increment user ID
    (var-set next-user-id (+ user-id u1))
    
    (ok user-id)
  )
)

;; Register new kitchen space
(define-public (register-kitchen-space (name (string-ascii 50)) (description (string-ascii 200)) (capacity uint) (equipment-list (list 20 (string-ascii 30))))
  (let
    (
      (kitchen-id (var-get next-kitchen-id))
      (base-rate (var-get hourly-rate))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> capacity u0) err-invalid-time)
    
    ;; Create kitchen space record
    (map-set kitchen-spaces
      {kitchen-id: kitchen-id}
      {
        name: name,
        description: description,
        capacity: capacity,
        hourly-rate: base-rate,
        equipment-list: equipment-list,
        active: true,
        maintenance-mode: false,
        total-bookings: u0,
        utilization-hours: u0
      }
    )
    
    ;; Increment kitchen ID
    (var-set next-kitchen-id (+ kitchen-id u1))
    
    (ok kitchen-id)
  )
)

;; Book kitchen time slot
(define-public (book-kitchen-slot (kitchen-id uint) (start-time uint) (end-time uint) (purpose (string-ascii 100)) (special-requirements (optional (string-ascii 200))))
  (let
    (
      (booking-id (var-get next-booking-id))
      (current-time u1000000)
      (user-data (unwrap! (get-user-by-principal tx-sender) err-not-found))
      (user-id (unwrap! (get user-id (map-get? user-by-principal {principal: tx-sender})) err-not-found))
      (kitchen (unwrap! (map-get? kitchen-spaces {kitchen-id: kitchen-id}) err-not-found))
      (duration-hours (/ (- end-time start-time) u3600))
      (total-cost (* duration-hours (get hourly-rate kitchen)))
    )
    (asserts! (get active user-data) err-unauthorized)
    (asserts! (get food-handler-cert user-data) err-unauthorized)
    (asserts! (get active kitchen) err-not-found)
    (asserts! (not (get maintenance-mode kitchen)) err-unauthorized)
    (asserts! (> end-time start-time) err-invalid-time)
    (asserts! (<= duration-hours (var-get max-booking-hours)) err-invalid-time)
    (asserts! (> start-time current-time) err-invalid-time)
    
    ;; Check for scheduling conflicts
    (asserts! (is-time-slot-available kitchen-id start-time end-time) err-time-conflict)
    
    ;; Create booking
    (map-set bookings
      {booking-id: booking-id}
      {
        user-id: user-id,
        kitchen-id: kitchen-id,
        start-time: start-time,
        end-time: end-time,
        duration-hours: duration-hours,
        total-cost: total-cost,
        payment-status: "pending",
        booking-status: "scheduled",
        purpose: purpose,
        special-requirements: special-requirements,
        access-code: none,
        check-in-time: none,
        check-out-time: none,
        created-at: current-time
      }
    )
    
    ;; Update user statistics
    (map-set kitchen-users
      {user-id: user-id}
      (merge user-data {
        total-bookings: (+ (get total-bookings user-data) u1),
        outstanding-balance: (+ (get outstanding-balance user-data) total-cost)
      })
    )
    
    ;; Update kitchen utilization
    (map-set kitchen-spaces
      {kitchen-id: kitchen-id}
      (merge kitchen {
        total-bookings: (+ (get total-bookings kitchen) u1),
        utilization-hours: (+ (get utilization-hours kitchen) duration-hours)
      })
    )
    
    ;; Reserve time slots
    (unwrap-panic (reserve-time-slots kitchen-id start-time end-time booking-id))
    
    ;; Increment booking ID
    (var-set next-booking-id (+ booking-id u1))
    
    (ok booking-id)
  )
)

;; Process payment for booking
(define-public (process-booking-payment (booking-id uint))
  (let
    (
      (booking (unwrap! (map-get? bookings {booking-id: booking-id}) err-not-found))
      (payment-id (var-get next-payment-id))
      (current-time u1000000)
    )
    (asserts! (is-eq (get payment-status booking) "pending") err-invalid-time)
    (asserts! (is-eq (get booking-status booking) "scheduled") err-invalid-time)
    
    ;; TODO: Implement STX payment processing
    
    ;; Update booking payment status
    (map-set bookings
      {booking-id: booking-id}
      (merge booking {payment-status: "paid"})
    )
    
    ;; Create payment record
    (map-set payment-records
      {payment-id: payment-id}
      {
        booking-id: booking-id,
        user-id: (get user-id booking),
        amount: (get total-cost booking),
        payment-method: "stx",
        transaction-hash: none,
        payment-date: current-time,
        refund-amount: u0,
        refund-date: none
      }
    )
    
    ;; Update user balance
    (let
      (
        (user (unwrap! (map-get? kitchen-users {user-id: (get user-id booking)}) err-not-found))
      )
      (map-set kitchen-users
        {user-id: (get user-id booking)}
        (merge user {
          outstanding-balance: (- (get outstanding-balance user) (get total-cost booking))
        })
      )
    )
    
    ;; Generate access code
    (let
      (
        (access-code (generate-access-code booking-id))
      )
      (map-set bookings
        {booking-id: booking-id}
        (merge booking {access-code: (some access-code)})
      )
    )
    
    ;; Increment payment ID
    (var-set next-payment-id (+ payment-id u1))
    
    (ok payment-id)
  )
)

;; Check in to kitchen session
(define-public (check-in-to-kitchen (booking-id uint) (access-code (string-ascii 10)))
  (let
    (
      (booking (unwrap! (map-get? bookings {booking-id: booking-id}) err-not-found))
      (current-time u1000000)
      (user-data (unwrap! (get-user-by-principal tx-sender) err-not-found))
    )
    (asserts! (is-eq (get principal user-data) tx-sender) err-unauthorized)
    (asserts! (is-eq (get payment-status booking) "paid") err-unauthorized)
    (asserts! (is-eq (get booking-status booking) "scheduled") err-invalid-time)
    (asserts! (is-eq (unwrap! (get access-code booking) err-unauthorized) access-code) err-unauthorized)
    (asserts! (<= (get start-time booking) current-time) err-invalid-time)
    (asserts! (> (get end-time booking) current-time) err-booking-expired)
    
    ;; Update booking with check-in time
    (map-set bookings
      {booking-id: booking-id}
      (merge booking {
        check-in-time: (some current-time),
        booking-status: "active"
      })
    )
    
    (ok true)
  )
)

;; Check out from kitchen session
(define-public (check-out-from-kitchen (booking-id uint))
  (let
    (
      (booking (unwrap! (map-get? bookings {booking-id: booking-id}) err-not-found))
      (current-time u1000000)
      (user-data (unwrap! (get-user-by-principal tx-sender) err-not-found))
    )
    (asserts! (is-eq (get principal user-data) tx-sender) err-unauthorized)
    (asserts! (is-eq (get booking-status booking) "active") err-invalid-time)
    (asserts! (is-some (get check-in-time booking)) err-invalid-time)
    
    ;; Calculate actual hours used
    (let
      (
        (check-in-time (unwrap-panic (get check-in-time booking)))
        (actual-hours (/ (- current-time check-in-time) u3600))
      )
      ;; Update booking completion
      (map-set bookings
        {booking-id: booking-id}
        (merge booking {
          check-out-time: (some current-time),
          booking-status: "completed"
        })
      )
      
      ;; Update user hours used
      (let
        (
          (user-id (get user-id booking))
          (user (unwrap! (map-get? kitchen-users {user-id: user-id}) err-not-found))
        )
        (map-set kitchen-users
          {user-id: user-id}
          (merge user {
            total-hours-used: (+ (get total-hours-used user) actual-hours)
          })
        )
      )
    )
    
    (ok true)
  )
)

;; Cancel booking
(define-public (cancel-booking (booking-id uint))
  (let
    (
      (booking (unwrap! (map-get? bookings {booking-id: booking-id}) err-not-found))
      (current-time u1000000)
      (user-data (unwrap! (get-user-by-principal tx-sender) err-not-found))
      (cancellation-deadline (- (get start-time booking) (var-get cancellation-window)))
    )
    (asserts! (is-eq (get principal user-data) tx-sender) err-unauthorized)
    (asserts! (is-eq (get booking-status booking) "scheduled") err-invalid-time)
    (asserts! (< current-time cancellation-deadline) err-cancellation-too-late)
    
    ;; Update booking status
    (map-set bookings
      {booking-id: booking-id}
      (merge booking {booking-status: "cancelled"})
    )
    
    ;; Process refund if payment was made
    (if (is-eq (get payment-status booking) "paid")
      (begin
        ;; TODO: Process refund
        (map-set bookings
          {booking-id: booking-id}
          (merge booking {payment-status: "refunded"})
        )
        
        ;; Update user balance
        (let
          (
            (user-id (get user-id booking))
            (user (unwrap! (map-get? kitchen-users {user-id: user-id}) err-not-found))
          )
          (map-set kitchen-users
            {user-id: user-id}
            (merge user {
              outstanding-balance: (- (get outstanding-balance user) (get total-cost booking))
            })
          )
        )
      )
      true
    )
    
    ;; Free up reserved time slots
    (unwrap-panic (free-time-slots (get kitchen-id booking) (get start-time booking) (get end-time booking) booking-id))
    
    (ok true)
  )
)

;; Private Helper Functions

(define-private (get-user-by-principal (user-principal principal))
  (match (map-get? user-by-principal {principal: user-principal})
    user-ref (map-get? kitchen-users {user-id: (get user-id user-ref)})
    none
  )
)

(define-private (is-time-slot-available (kitchen-id uint) (start-time uint) (end-time uint))
  ;; Simplified availability check - in practice would check hour-by-hour
  (let
    (
      (kitchen (unwrap! (map-get? kitchen-spaces {kitchen-id: kitchen-id}) false))
      (hour-slot (/ start-time u3600))
    )
    (match (map-get? kitchen-availability {kitchen-id: kitchen-id, hour-slot: hour-slot})
      slot-info (and
        (get available slot-info)
        (< (get current-bookings slot-info) (get max-capacity slot-info))
        (not (get maintenance-scheduled slot-info))
      )
      true ;; If no availability record, assume available
    )
  )
)

(define-private (reserve-time-slots (kitchen-id uint) (start-time uint) (end-time uint) (booking-id uint))
  (let
    (
      (hour-slot (/ start-time u3600))
    )
    ;; Simplified reservation - would iterate through all hours in practice
    (map-set kitchen-availability
      {kitchen-id: kitchen-id, hour-slot: hour-slot}
      {
        available: true,
        current-bookings: u1, ;; Would increment existing count
        max-capacity: u4, ;; Default capacity
        hourly-rate: (var-get hourly-rate),
        maintenance-scheduled: false
      }
    )
    (ok true)
  )
)

(define-private (free-time-slots (kitchen-id uint) (start-time uint) (end-time uint) (booking-id uint))
  (let
    (
      (hour-slot (/ start-time u3600))
    )
    ;; Simplified freeing - would iterate through all hours in practice
    (match (map-get? kitchen-availability {kitchen-id: kitchen-id, hour-slot: hour-slot})
      slot-info (map-set kitchen-availability
        {kitchen-id: kitchen-id, hour-slot: hour-slot}
        (merge slot-info {
          current-bookings: (if (> (get current-bookings slot-info) u0) 
            (- (get current-bookings slot-info) u1) 
            u0)
        })
      )
      true
    )
    (ok true)
  )
)

(define-private (generate-access-code (booking-id uint))
  ;; Simplified access code generation - in practice would be more secure
  ;; Keep it within 10 characters limit
  (let
    (
      (code-num (mod booking-id u100000)) ;; Limit to 5 digits max
    )
    "KC12345678" ;; Fixed 10-character code for now - in practice would be dynamic
  )
)

;; Read-only Functions

(define-read-only (get-kitchen-user (user-id uint))
  (map-get? kitchen-users {user-id: user-id})
)

(define-read-only (get-user-info (user-principal principal))
  (get-user-by-principal user-principal)
)

(define-read-only (get-kitchen-space (kitchen-id uint))
  (map-get? kitchen-spaces {kitchen-id: kitchen-id})
)

(define-read-only (get-booking (booking-id uint))
  (map-get? bookings {booking-id: booking-id})
)

(define-read-only (get-kitchen-availability (kitchen-id uint) (hour-slot uint))
  (map-get? kitchen-availability {kitchen-id: kitchen-id, hour-slot: hour-slot})
)

(define-read-only (get-payment-record (payment-id uint))
  (map-get? payment-records {payment-id: payment-id})
)

(define-read-only (get-scheduling-stats)
  {
    total-users: (- (var-get next-user-id) u1),
    total-kitchens: (- (var-get next-kitchen-id) u1),
    total-bookings: (- (var-get next-booking-id) u1),
    hourly-rate: (var-get hourly-rate),
    max-booking-hours: (var-get max-booking-hours),
    cancellation-window: (var-get cancellation-window)
  }
)

(define-read-only (check-booking-conflicts (kitchen-id uint) (start-time uint) (end-time uint))
  (let
    (
      (hour-slot (/ start-time u3600))
    )
    (match (map-get? kitchen-availability {kitchen-id: kitchen-id, hour-slot: hour-slot})
      slot-info {
        conflicts: (>= (get current-bookings slot-info) (get max-capacity slot-info)),
        current-bookings: (get current-bookings slot-info),
        max-capacity: (get max-capacity slot-info),
        available: (get available slot-info)
      }
      {
        conflicts: false,
        current-bookings: u0,
        max-capacity: u4,
        available: true
      }
    )
  )
)

;; title: kitchen-scheduling
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

