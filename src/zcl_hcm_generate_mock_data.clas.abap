CLASS zcl_hcm_generate_mock_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_hcm_generate_mock_data IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    DATA: lt_job_offers TYPE STANDARD TABLE OF zhcm_joboffer,
          lt_pipe_steps TYPE STANDARD TABLE OF zhcm_pipe_tmpl.

    TRY.
      GET TIME STAMP FIELD DATA(lv_ts).

      " Clear existing data (optional, to avoid duplicates if you run it multiple times)
      DELETE FROM zhcm_joboffer.
      DELETE FROM zhcm_pipe_tmpl.

      " ---------------------------------------------------------------------
      " Offer 1: Senior ABAP Developer
      " ---------------------------------------------------------------------
      DATA(lv_offer1_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer1_id
        title = 'Senior ABAP RAP Developer'
        description = 'We are looking for an experienced SAP ABAP developer with strong RAP skills to build our next generation APIs.'
        department = 'IT & Engineering'
        required_skills = 'ABAP, RAP, OData V4, Fiori Elements'
        experience_level = 'Senior'
        contract_type = 'Full-Time'
        location = 'Remote, US'
        positions_needed = 2
        positions_filled = 0
        salary_min = 120000
        salary_max = 160000
        currency_code = 'USD'
        status = 'P' " P = Published
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      " Insert Pipeline Steps for Offer 1
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer1_id step_name = 'Screening' step_order = 1 step_type = 'SCREEN' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer1_id step_name = 'Technical Interview' step_order = 2 step_type = 'INTERV' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer1_id step_name = 'Offer' step_order = 3 step_type = 'OFFER' ) TO lt_pipe_steps.

      " ---------------------------------------------------------------------
      " Offer 2: SAP Fiori Consultant
      " ---------------------------------------------------------------------
      DATA(lv_offer2_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer2_id
        title = 'SAP Fiori Frontend Engineer'
        description = 'Join our consulting team to build beautiful UI5 and React apps for SAP BTP.'
        department = 'Consulting'
        required_skills = 'SAPUI5, React, Node.js, BTP'
        experience_level = 'Mid-Level'
        contract_type = 'Contract'
        location = 'Hybrid, London'
        positions_needed = 1
        positions_filled = 0
        salary_min = 80000
        salary_max = 110000
        currency_code = 'GBP'
        status = 'P' " P = Published
        valid_until = '20261031'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      " Insert Pipeline Steps for Offer 2
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer2_id step_name = 'AI Resume Parse' step_order = 1 step_type = 'SCREEN' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer2_id step_name = 'Manager Interview' step_order = 2 step_type = 'INTERV' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer2_id step_name = 'Background Check' step_order = 3 step_type = 'CHECK' ) TO lt_pipe_steps.

      " Save to Database
      INSERT zhcm_joboffer FROM TABLE @lt_job_offers.
      INSERT zhcm_pipe_tmpl FROM TABLE @lt_pipe_steps.

      COMMIT WORK.
      out->write( 'Mock data generated successfully!' ).
      out->write( |Inserted { lines( lt_job_offers ) } Job Offers and { lines( lt_pipe_steps ) } Pipeline Steps.| ).

    CATCH cx_uuid_error INTO DATA(lx_uuid).
      out->write( 'Error generating UUID' ).
    ENDTRY.

  ENDMETHOD.
ENDCLASS.

