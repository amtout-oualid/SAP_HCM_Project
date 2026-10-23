"! Fills the status and lookup tables used by the value helps, and aligns old position statuses.
"! Safe to run several times: values are inserted or updated (MODIFY), nothing is deleted.
CLASS zcl_hcm_populate_status DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_hcm_populate_status IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA lt_appstat  TYPE STANDARD TABLE OF zhcm_appstat   WITH EMPTY KEY.
    DATA lt_empstat  TYPE STANDARD TABLE OF zhcm_empstat   WITH EMPTY KEY.
    DATA lt_genstat  TYPE STANDARD TABLE OF zhcm_genstat   WITH EMPTY KEY.
    DATA lt_jobstat  TYPE STANDARD TABLE OF zhcm_jobstat   WITH EMPTY KEY.
    DATA lt_explvl   TYPE STANDARD TABLE OF zhcm_explvl    WITH EMPTY KEY.
    DATA lt_conttyp  TYPE STANDARD TABLE OF zhcm_conttyp   WITH EMPTY KEY.
    DATA lt_steptype TYPE STANDARD TABLE OF zhcm_step_type WITH EMPTY KEY.

    " Application status (ZI_HCM_VH_AppStatus)
    lt_appstat = VALUE #( ( status = 'N' description = 'New' )
                          ( status = 'H' description = 'On Hold' )
                          ( status = 'A' description = 'Accepted' )
                          ( status = 'R' description = 'Rejected' ) ).

    " Employee status (ZI_HCM_VH_EmpStatus)
    lt_empstat = VALUE #( ( status = 'A' description = 'Active' )
                          ( status = 'S' description = 'Suspended' )
                          ( status = 'T' description = 'Terminated' ) ).

    " Org unit status A/I (ZI_HCM_VH_GenericStatus) and position status V/F/Z (ZI_HCM_VH_PosStatus)
    lt_genstat = VALUE #( ( status = 'A' description = 'Active' )
                          ( status = 'I' description = 'Inactive' )
                          ( status = 'V' description = 'Vacant' )
                          ( status = 'F' description = 'Filled' )
                          ( status = 'Z' description = 'Frozen' ) ).

    " Job offer status (ZI_HCM_VH_JobStatus)
    lt_jobstat = VALUE #( ( status = 'D' description = 'Draft' )
                          ( status = 'P' description = 'Published' )
                          ( status = 'C' description = 'Closed' ) ).

    " Experience levels, contract types and pipeline step types
    lt_explvl = VALUE #( ( exp_level = 'Entry Level'    description = '0-2 years' )
                         ( exp_level = 'Mid Level'      description = '3-5 years' )
                         ( exp_level = 'Senior Level'   description = '5+ years' )
                         ( exp_level = 'Lead / Manager' description = 'Leadership' ) ).

    lt_conttyp = VALUE #( ( contract_type = 'Full-time'  description = 'Permanent Full-Time' )
                          ( contract_type = 'Part-time'  description = 'Permanent Part-Time' )
                          ( contract_type = 'Contract'   description = 'Fixed-term Contract' )
                          ( contract_type = 'Freelance'  description = 'Freelancer / External' )
                          ( contract_type = 'Internship' description = 'Intern / Trainee' ) ).

    lt_steptype = VALUE #( ( step_type = 'SCREEN' description = 'AI / HR Screening' )
                           ( step_type = 'INTERV' description = 'Interview' )
                           ( step_type = 'TECH'   description = 'Technical Test' )
                           ( step_type = 'OFFER'  description = 'Offer Stage' )
                           ( step_type = 'BGC'    description = 'Background Check' ) ).

    MODIFY zhcm_appstat   FROM TABLE @lt_appstat.
    MODIFY zhcm_empstat   FROM TABLE @lt_empstat.
    MODIFY zhcm_genstat   FROM TABLE @lt_genstat.
    MODIFY zhcm_jobstat   FROM TABLE @lt_jobstat.
    MODIFY zhcm_explvl    FROM TABLE @lt_explvl.
    MODIFY zhcm_conttyp   FROM TABLE @lt_conttyp.
    MODIFY zhcm_step_type FROM TABLE @lt_steptype.

    " Old position codes (A, O, P or empty) become V = Vacant ...
    UPDATE zhcm_position SET status = 'V'
      WHERE status <> 'V' AND status <> 'F' AND status <> 'Z'.
    DATA(lv_vacant) = sy-dbcnt.

    " ... and a position that an employee currently occupies is F = Filled
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    UPDATE zhcm_position SET status = 'F'
      WHERE status = 'V'
        AND position_id IN ( SELECT position_id FROM zhcm_orgassign
                               WHERE valid_to >= @lv_today ).
    DATA(lv_filled) = sy-dbcnt.

    " Org units without status are active
    UPDATE zhcm_orgunit SET status = 'A' WHERE status = ' '.

    COMMIT WORK.

    out->write( 'Status and lookup values are up to date.' ).
    out->write( |Positions set to Vacant: { lv_vacant }, set to Filled: { lv_filled }.| ).
  ENDMETHOD.
ENDCLASS.
