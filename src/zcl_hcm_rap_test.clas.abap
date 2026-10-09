" ABAP Unit tests of the Talently RAP business objects (report Chapter 5, Table 5.1).
" The persistence is replaced by test doubles (CDS and ABAP SQL test double frameworks),
" so the tests neither read nor change the real data.
"! @testing BDEF:ZI_HCM_JOBOFFER
"! @testing BDEF:ZI_HCM_CANDIDATE
"! @testing BDEF:ZI_HCM_ONBOARDING
CLASS zcl_hcm_rap_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION MEDIUM.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA cds_test_environment TYPE REF TO if_cds_test_environment.
    CLASS-DATA sql_test_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    "! 1. Publishing an offer without pipeline steps is rejected
    METHODS publish_without_steps_fails FOR TESTING RAISING cx_static_check.
    "! 2. A candidate cannot apply twice to the same offer
    METHODS duplicate_application_fails FOR TESTING RAISING cx_static_check.
    "! 3. Accepting a candidate for the last open position closes the offer
    METHODS accept_last_position_closes FOR TESTING RAISING cx_static_check.
    "! 4. Approving the onboarding form creates the employee with its child records
    METHODS approve_creates_employee FOR TESTING RAISING cx_static_check.

    METHODS create_published_offer
      IMPORTING iv_positions_needed TYPE i
      RETURNING VALUE(rv_offer_id)  TYPE sysuuid_x16.
    METHODS new_uuid
      RETURNING VALUE(rv_uuid) TYPE sysuuid_x16.
ENDCLASS.



CLASS zcl_hcm_rap_test IMPLEMENTATION.

  METHOD class_setup.
    " The onboarding form is saved by the RAP framework: its CDS entity is doubled
    cds_test_environment = cl_cds_test_environment=>create_for_multiple_cds(
                             VALUE #( ( i_for_entity = 'ZI_HCM_ONBOARDING' ) ) ).

    " Tables read or written with ABAP SQL by the behavior implementations
    sql_test_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #(
                             ( 'ZHCM_JOBOFFER' )  ( 'ZHCM_PIPE_TMPL' ) ( 'ZHCM_APPLICATN' ) ( 'ZHCM_PIPE_PROG' )
                             ( 'ZHCM_CANDIDATE' ) ( 'ZHCM_TALNTPOOL' ) ( 'ZHCM_HR_MAIL' )
                             ( 'ZHCM_EMPLOYEE' )  ( 'ZHCM_CONTACT' )   ( 'ZHCM_BANKDETL' )  ( 'ZHCM_EMERGENCY' )
                             ( 'ZHCM_ORGASSIGN' ) ( 'ZHCM_EMP_HIST' )  ( 'ZHCM_ORGUNIT' )   ( 'ZHCM_POSITION' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    cds_test_environment->destroy( ).
    sql_test_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    cds_test_environment->clear_doubles( ).
    sql_test_environment->clear_doubles( ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.                                 "#EC CI_ROLLBACK
  ENDMETHOD.

  METHOD new_uuid.
    TRY.
        rv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        cl_abap_unit_assert=>fail( msg = 'UUID could not be created' ).
    ENDTRY.
  ENDMETHOD.

  METHOD create_published_offer.
    MODIFY ENTITIES OF zi_hcm_joboffer
      ENTITY JobOffer
        CREATE FIELDS ( Title Department PositionsNeeded )
        WITH VALUE #( ( %cid = 'OFFER' Title = 'Unit Test Offer' Department = 'Unit Test'
                        PositionsNeeded = iv_positions_needed ) )
        CREATE BY \_Steps
        FIELDS ( StepOrder StepName StepType )
        WITH VALUE #( ( %cid_ref = 'OFFER'
                        %target  = VALUE #( ( %cid = 'STEP_1' StepOrder = 1 StepName = 'Interview' StepType = 'INTERV' ) ) ) )
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'The test offer could not be created' ).

    rv_offer_id = ls_mapped-joboffer[ 1 ]-OfferId.

    MODIFY ENTITIES OF zi_hcm_joboffer
      ENTITY JobOffer
        EXECUTE publishOffer FROM VALUE #( ( OfferId = rv_offer_id ) )
      FAILED ls_failed.
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'The test offer could not be published' ).
  ENDMETHOD.

  METHOD publish_without_steps_fails.
    " Given an offer without pipeline steps
    MODIFY ENTITIES OF zi_hcm_joboffer
      ENTITY JobOffer
        CREATE FIELDS ( Title Department PositionsNeeded )
        WITH VALUE #( ( %cid = 'OFFER' Title = 'Unit Test Offer' Department = 'Unit Test' PositionsNeeded = 1 ) )
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'The offer could not be created' ).

    " When it is published and saved
    MODIFY ENTITIES OF zi_hcm_joboffer
      ENTITY JobOffer
        EXECUTE publishOffer FROM VALUE #( ( OfferId = ls_mapped-joboffer[ 1 ]-OfferId ) )
      FAILED ls_failed.
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'The publish action must be available for a draft offer' ).

    COMMIT ENTITIES
      RESPONSE OF zi_hcm_joboffer
      FAILED DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    " Then the save is rejected by validateBeforePublish
    cl_abap_unit_assert=>assert_subrc( exp = 4 msg = 'The save must be rejected' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_commit_failed-joboffer
                                             msg = 'Publishing without pipeline steps must be rejected' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_commit_reported-joboffer
                                             msg = 'An error message is expected' ).
  ENDMETHOD.

  METHOD duplicate_application_fails.
    " Given a published offer and a candidate
    DATA(lv_offer_id) = create_published_offer( 1 ).

    MODIFY ENTITIES OF zi_hcm_candidate
      ENTITY Candidate
        CREATE FIELDS ( FirstName LastName Email )
        WITH VALUE #( ( %cid = 'CANDIDATE' FirstName = 'Unit' LastName = 'Tester' Email = 'unit.tester@example.com' ) )
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'The candidate could not be created' ).
    DATA(lv_candidate_id) = ls_mapped-candidate[ 1 ]-CandidateId.

    " When the candidate applies twice to the same offer
    MODIFY ENTITIES OF zi_hcm_candidate
      ENTITY Candidate
        EXECUTE applyToJob FROM VALUE #( ( CandidateId = lv_candidate_id
                                           %param      = VALUE #( OfferId   = lv_offer_id
                                                                  ResumeUrl = 'https://example.com/cv.pdf' ) ) )
      FAILED DATA(ls_first_failed).

    MODIFY ENTITIES OF zi_hcm_candidate
      ENTITY Candidate
        EXECUTE applyToJob FROM VALUE #( ( CandidateId = lv_candidate_id
                                           %param      = VALUE #( OfferId   = lv_offer_id
                                                                  ResumeUrl = 'https://example.com/cv.pdf' ) ) )
      FAILED DATA(ls_second_failed).

    " Then the first application is accepted and the second one is refused
    cl_abap_unit_assert=>assert_initial( act = ls_first_failed msg = 'The first application must be accepted' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_second_failed-candidate
                                             msg = 'A second application to the same offer must be refused' ).
  ENDMETHOD.

  METHOD accept_last_position_closes.
    " Given a published offer for one position and an application at its last (single) step
    DATA(lv_offer_id) = create_published_offer( 1 ).
    DATA(lv_candidate_id) = new_uuid( ).

    MODIFY ENTITIES OF zi_hcm_joboffer
      ENTITY JobOffer
        CREATE BY \_Applications
        FIELDS ( CandidateId ResumeUrl )
        WITH VALUE #( ( OfferId = lv_offer_id
                        %target = VALUE #( ( %cid        = 'APPLICATION'
                                             CandidateId = lv_candidate_id
                                             ResumeUrl   = 'https://example.com/cv.pdf' ) ) ) )
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'The application could not be created' ).

    " When HR accepts the candidate
    MODIFY ENTITIES OF zi_hcm_joboffer
      ENTITY Application
        EXECUTE acceptToPost FROM VALUE #( ( ApplicationId = ls_mapped-application[ 1 ]-ApplicationId
                                             %param        = VALUE #( StartDate = cl_abap_context_info=>get_system_date( )
                                                                      Notes     = 'Unit test' ) ) )
      FAILED ls_failed.
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Accept to Post must be available at the last step' ).

    " Then the only position is filled and the offer is closed
    READ ENTITIES OF zi_hcm_joboffer
      ENTITY JobOffer FIELDS ( Status PositionsFilled ) WITH VALUE #( ( OfferId = lv_offer_id ) )
      RESULT DATA(lt_offers).
    cl_abap_unit_assert=>assert_equals( exp = 1   act = lt_offers[ 1 ]-PositionsFilled msg = 'One position must be filled' ).
    cl_abap_unit_assert=>assert_equals( exp = 'C' act = lt_offers[ 1 ]-Status          msg = 'The offer must be closed' ).
  ENDMETHOD.

  METHOD approve_creates_employee.
    " Given an accepted application for a vacant position (test data in the doubles)
    DATA(lv_org_unit_id)    = new_uuid( ).
    DATA(lv_position_id)    = new_uuid( ).
    DATA(lv_offer_id)       = new_uuid( ).
    DATA(lv_application_id) = new_uuid( ).
    DATA(lv_candidate_id)   = new_uuid( ).

    DATA lt_orgunits  TYPE STANDARD TABLE OF zhcm_orgunit   WITH EMPTY KEY.
    DATA lt_positions TYPE STANDARD TABLE OF zhcm_position  WITH EMPTY KEY.
    DATA lt_offers    TYPE STANDARD TABLE OF zhcm_joboffer  WITH EMPTY KEY.
    DATA lt_apps      TYPE STANDARD TABLE OF zhcm_applicatn WITH EMPTY KEY.

    lt_orgunits  = VALUE #( ( org_unit_id = lv_org_unit_id unit_name = 'Unit Test Department' status = 'A' ) ).
    lt_positions = VALUE #( ( position_id = lv_position_id org_unit_id = lv_org_unit_id
                              job_title = 'Unit Test Engineer' status = 'V' ) ).
    lt_offers    = VALUE #( ( offer_id = lv_offer_id title = 'Unit Test Engineer' department = 'Unit Test Department'
                              position_id = lv_position_id status = 'C' positions_needed = 1 positions_filled = 1 ) ).
    lt_apps      = VALUE #( ( application_id = lv_application_id offer_id = lv_offer_id candidate_id = lv_candidate_id
                              overall_status = 'A' current_step_order = 1 ) ).
    sql_test_environment->insert_test_data( lt_orgunits ).
    sql_test_environment->insert_test_data( lt_positions ).
    sql_test_environment->insert_test_data( lt_offers ).
    sql_test_environment->insert_test_data( lt_apps ).

    " and a complete onboarding form submitted by the candidate
    MODIFY ENTITIES OF zi_hcm_onboarding
      ENTITY Onboarding
        CREATE FIELDS ( ApplicationId FirstName LastName DateOfBirth NationalId Address Phone PersonalEmail
                        BankName BankAccount Iban EmergencyName EmergencyPhone EmergencyRelation )
        WITH VALUE #( ( %cid = 'FORM' ApplicationId = lv_application_id
                        FirstName = 'Unit' LastName = 'Tester' DateOfBirth = '19990101' NationalId = 'UT000001'
                        Address = '1 Test Street' Phone = '+212600000000' PersonalEmail = 'unit.tester@example.com'
                        BankName = 'Test Bank' BankAccount = '0001' Iban = 'MA00TEST0001'
                        EmergencyName = 'Test Contact' EmergencyPhone = '+212600000001' EmergencyRelation = 'Sibling' ) )
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed).
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'The onboarding form could not be created' ).
    DATA(lv_form_id) = ls_mapped-onboarding[ 1 ]-FormId.

    MODIFY ENTITIES OF zi_hcm_onboarding
      ENTITY Onboarding EXECUTE submitForm FROM VALUE #( ( FormId = lv_form_id ) )
      FAILED ls_failed.
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'The form could not be submitted' ).

    " When HR approves the form
    MODIFY ENTITIES OF zi_hcm_onboarding
      ENTITY Onboarding EXECUTE approveAndCreateEmployee FROM VALUE #( ( FormId = lv_form_id ) )
      FAILED ls_failed.
    cl_abap_unit_assert=>assert_initial( act = ls_failed msg = 'Approve & Hire must be available for a submitted form' ).

    READ ENTITIES OF zi_hcm_onboarding
      ENTITY Onboarding FIELDS ( Status EmployeeId ) WITH VALUE #( ( FormId = lv_form_id ) )
      RESULT DATA(lt_forms).
    cl_abap_unit_assert=>assert_equals( exp = 'A' act = lt_forms[ 1 ]-Status msg = 'The form must be approved' ).
    DATA(lv_employee_id) = lt_forms[ 1 ]-EmployeeId.
    cl_abap_unit_assert=>assert_not_initial( act = lv_employee_id msg = 'The employee ID must be set on the form' ).

    " and the transaction is saved
    COMMIT ENTITIES
      RESPONSE OF zi_hcm_onboarding
      FAILED DATA(ls_commit_failed).
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The approval could not be saved' ).
    cl_abap_unit_assert=>assert_initial( act = ls_commit_failed msg = 'The approval could not be saved' ).

    " Then the employee exists with its contact, bank, emergency and assignment records
    SELECT SINGLE employee_status FROM zhcm_employee WHERE employee_id = @lv_employee_id INTO @DATA(lv_employee_status).
    cl_abap_unit_assert=>assert_equals( exp = 'A' act = lv_employee_status msg = 'The employee must be active' ).

    SELECT COUNT(*) FROM zhcm_contact   WHERE employee_id = @lv_employee_id INTO @DATA(lv_contacts).
    SELECT COUNT(*) FROM zhcm_bankdetl  WHERE employee_id = @lv_employee_id INTO @DATA(lv_banks).
    SELECT COUNT(*) FROM zhcm_emergency WHERE employee_id = @lv_employee_id INTO @DATA(lv_emergency).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lv_contacts  msg = 'One contact record expected' ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lv_banks     msg = 'One bank record expected' ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lv_emergency msg = 'One emergency contact expected' ).

    SELECT SINGLE position_id FROM zhcm_orgassign WHERE employee_id = @lv_employee_id INTO @DATA(lv_assigned_position).
    cl_abap_unit_assert=>assert_equals( exp = lv_position_id act = lv_assigned_position
                                        msg = 'The employee must be assigned to the vacant position' ).

    " and the position is now filled
    SELECT SINGLE status FROM zhcm_position WHERE position_id = @lv_position_id INTO @DATA(lv_position_status).
    cl_abap_unit_assert=>assert_equals( exp = 'F' act = lv_position_status msg = 'The position must be filled' ).
  ENDMETHOD.

ENDCLASS.
