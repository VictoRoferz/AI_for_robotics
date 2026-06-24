(define (domain tabletop)
  (:requirements :strips :typing)

  (:types item location)

  (:predicates
    (at ?o - item ?l - location)
    (clear ?l - location)
    (holding ?o - item)
    (hand_empty)
  )

  ;; Pick up an item from a location.
  ;; Pre:  item is at that location AND the gripper is free.
  ;; Post: gripper holds the item, location becomes clear.
  (:action pick
    :parameters (?o - item ?from - location)
    :precondition (and (at ?o ?from) (hand_empty))
    :effect (and
              (not (at ?o ?from))
              (not (hand_empty))
              (holding ?o)
              (clear ?from)))

  ;; Place a held item onto a clear location.
  ;; Pre:  gripper holds the item AND destination is clear.
  ;; Post: item is at destination, gripper is free.
  (:action place
    :parameters (?o - item ?to - location)
    :precondition (and (holding ?o) (clear ?to))
    :effect (and
              (not (holding ?o))
              (not (clear ?to))
              (at ?o ?to)
              (hand_empty)))
)
