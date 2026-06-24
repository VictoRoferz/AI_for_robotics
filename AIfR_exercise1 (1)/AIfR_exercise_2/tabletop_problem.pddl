(define (problem tabletop-rearrange)
  (:domain tabletop)

  (:objects
    cup mug plate - item
    loc_a loc_b loc_c loc_d loc_e - location
  )

  ;; Initial layout (top view):
  ;;   loc_a: cup   loc_b: (empty)   loc_c: mug   loc_d: (empty)   loc_e: plate
  (:init
    (at cup   loc_a)
    (at mug   loc_c)
    (at plate loc_e)
    (clear loc_b)
    (clear loc_d)
    (hand_empty)
  )

  ;; Goal: swap cup and mug (plate may stay anywhere).
  (:goal (and
    (at cup loc_c)
    (at mug loc_a)
  ))
)
