CLASS zcl_hcm_generate_mock_datatest DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_hcm_generate_mock_datatest IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA: lt_joboffer TYPE TABLE OF zhcm_joboffer,
          lt_steps    TYPE TABLE OF zhcm_pipe_tmpl,
          lv_offer_id TYPE sysuuid_x16,
          lv_step_id  TYPE sysuuid_x16,
          lv_time     TYPE timestamp.

    GET TIME STAMP FIELD lv_time.

    " 1. Clear all old data to start fresh
    DELETE FROM zhcm_joboffer.
    DELETE FROM zhcm_pipe_tmpl.
    DELETE FROM zhcm_applicatn.
    DELETE FROM zhcm_pipe_prog.
    DELETE FROM zhcm_candidate.

    out->write( 'Old data deleted.' ).

    " 2. Generate 12 Job Offers
    DO 12 TIMES.
      TRY.
          lv_offer_id = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error.
      ENDTRY.

      DATA(ls_offer) = VALUE zhcm_joboffer(
        offer_id         = lv_offer_id
        status           = 'P' " Published
        created_at       = lv_time
        currency_code    = 'USD'
        valid_until      = '20301231'
        positions_needed = 3
        positions_filled = 0
      ).

      " Assign Different Scenarios based on the loop index
      IF sy-index <= 3.
        ls_offer-title            = |Senior Full-Stack Engineer { sy-index }|.
        ls_offer-department       = 'Engineering'.
        ls_offer-experience_level = 'Senior Level'.
        ls_offer-contract_type    = 'Full-time'.
        ls_offer-location         = 'Remote'.
        ls_offer-salary_min       = 90000.
        ls_offer-salary_max       = 140000.
        APPEND ls_offer TO lt_joboffer.

        " Scenario 1: Standard 4-Step Pipeline
        DATA(lt_standard_names) = VALUE string_table( ( `Screening` ) ( `Interview` ) ( `Offer` ) ( `Onboarding` ) ).
        LOOP AT lt_standard_names INTO DATA(lv_name).
          TRY.
              lv_step_id = cl_system_uuid=>create_uuid_x16_static( ).
            CATCH cx_uuid_error.
          ENDTRY.
          APPEND VALUE #( template_id = lv_step_id  offer_id = lv_offer_id  step_order = sy-tabix  step_name = lv_name ) TO lt_steps.
        ENDLOOP.

      ELSEIF sy-index <= 6.
        ls_offer-title            = |Product Manager { sy-index }|.
        ls_offer-department       = 'Product'.
        ls_offer-experience_level = 'Mid Level'.
        ls_offer-contract_type    = 'Full-time'.
        ls_offer-location         = 'Hybrid - New York'.
        ls_offer-salary_min       = 100000.
        ls_offer-salary_max       = 130000.
        APPEND ls_offer TO lt_joboffer.

        " Scenario 2: Long 5-Step Pipeline
        DATA(lt_long_names) = VALUE string_table( ( `Screening` ) ( `Technical Interview` ) ( `HR Interview` ) ( `Offer` ) ( `Onboarding` ) ).
        LOOP AT lt_long_names INTO lv_name.
          TRY.
              lv_step_id = cl_system_uuid=>create_uuid_x16_static( ).
            CATCH cx_uuid_error.
          ENDTRY.
          APPEND VALUE #( template_id = lv_step_id  offer_id = lv_offer_id  step_order = sy-tabix  step_name = lv_name ) TO lt_steps.
        ENDLOOP.

      ELSEIF sy-index <= 9.
        ls_offer-title            = |Freelance UI Designer { sy-index }|.
        ls_offer-department       = 'Design'.
        ls_offer-experience_level = 'Mid Level'.
        ls_offer-contract_type    = 'Contract'.
        ls_offer-location         = 'Remote'.
        ls_offer-salary_min       = 50000.
        ls_offer-salary_max       = 80000.
        APPEND ls_offer TO lt_joboffer.

        " Scenario 3: Short 3-Step Pipeline
        DATA(lt_short_names) = VALUE string_table( ( `Portfolio Review` ) ( `Interview` ) ( `Offer` ) ).
        LOOP AT lt_short_names INTO lv_name.
          TRY.
              lv_step_id = cl_system_uuid=>create_uuid_x16_static( ).
            CATCH cx_uuid_error.
          ENDTRY.
          APPEND VALUE #( template_id = lv_step_id  offer_id = lv_offer_id  step_order = sy-tabix  step_name = lv_name ) TO lt_steps.
        ENDLOOP.

      ELSE.
        ls_offer-title            = |Data Entry Intern { sy-index }|.
        ls_offer-department       = 'Operations'.
        ls_offer-experience_level = 'Entry Level'.
        ls_offer-contract_type    = 'Internship'.
        ls_offer-location         = 'On-site'.
        ls_offer-salary_min       = 30000.
        ls_offer-salary_max       = 40000.
        APPEND ls_offer TO lt_joboffer.

        " Scenario 4: No Pipeline Steps (0 steps generated)
      ENDIF.

    ENDDO.

    " 3. Insert into database
    INSERT zhcm_joboffer FROM TABLE @lt_joboffer.
    IF sy-subrc = 0.
      out->write( |Successfully inserted 12 Job Offers!| ).
    ENDIF.

    INSERT zhcm_pipe_tmpl FROM TABLE @lt_steps.
    IF sy-subrc = 0.
      out->write( |Successfully inserted { lines( lt_steps ) } Pipeline Steps!| ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.

