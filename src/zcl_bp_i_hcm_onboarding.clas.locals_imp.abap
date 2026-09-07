CLASS lcl_buffer DEFINITION.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_employee_data,
             form_id         TYPE sysuuid_x16,
             application_id  TYPE sysuuid_x16,
             first_name      TYPE string,
             last_name       TYPE string,
             nationality     TYPE string,
             date_of_birth   TYPE d,
             place_of_birth  TYPE string,
             gender          TYPE string,
             marital_status  TYPE string,
             personal_email  TYPE string,
             phone           TYPE string,
             address         TYPE string,
             bank_name       TYPE string,
             bank_account    TYPE string,
             iban            TYPE string,
           END OF ty_employee_data.
    CLASS-DATA: mt_employee_data TYPE TABLE OF ty_employee_data.
ENDCLASS.
CLASS lcl_buffer IMPLEMENTATION.
ENDCLASS.

CLASS lhc_onboarding DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Onboarding RESULT result.
    METHODS submitForm FOR MODIFY
      IMPORTING keys FOR ACTION Onboarding~submitForm RESULT result.
    METHODS approveAndCreateEmployee FOR MODIFY
      IMPORTING keys FOR ACTION Onboarding~approveAndCreateEmployee RESULT result.
    METHODS rejectForm FOR MODIFY
      IMPORTING keys FOR ACTION Onboarding~rejectForm RESULT result.
ENDCLASS.

CLASS lhc_onboarding IMPLEMENTATION.
  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky                             = key-%tky
                      %update                          = if_abap_behv=>auth-allowed
                      %delete                          = if_abap_behv=>auth-allowed
                      %action-submitForm               = if_abap_behv=>auth-allowed
                      %action-approveAndCreateEmployee = if_abap_behv=>auth-allowed
                      %action-rejectForm               = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD submitForm.
    GET TIME STAMP FIELD DATA(lv_ts).
    MODIFY ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding UPDATE FIELDS ( Status SubmittedAt )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'S' SubmittedAt = lv_ts ) ).

    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD approveAndCreateEmployee.
    GET TIME STAMP FIELD DATA(lv_now).

    " 1. Mark onboarding record as Approved, stamped with Approver & Timestamp
    MODIFY ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding UPDATE FIELDS ( Status ApprovedBy ApprovedAt )
      WITH VALUE #( FOR key IN keys (
        %tky       = key-%tky
        Status     = 'A'
        ApprovedBy = sy-uname
        ApprovedAt = lv_now
      ) ).

    " 2. Read full form data for all approved records
    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_forms).

    " 3. Buffer employee data — actual employee creation happens in lsc save_modified
    LOOP AT lt_forms INTO DATA(ls_form).
      APPEND VALUE #(
        form_id        = ls_form-FormId
        application_id = ls_form-ApplicationId
        first_name     = ls_form-FirstName
        last_name      = ls_form-LastName
        nationality    = ls_form-Nationality
        date_of_birth  = ls_form-DateOfBirth
        place_of_birth = ls_form-PlaceOfBirth
        gender         = ls_form-Gender
        marital_status = ls_form-MaritalStatus
        personal_email = ls_form-PersonalEmail
        phone          = ls_form-Phone
        address        = ls_form-Address
        bank_name      = ls_form-BankName
        bank_account   = ls_form-BankAccount
        iban           = ls_form-Iban
      ) TO lcl_buffer=>mt_employee_data.
    ENDLOOP.

    " 4. Return updated onboarding record to caller
    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD rejectForm.
    MODIFY ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding UPDATE FIELDS ( Status )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'P' ) ).

    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.
ENDCLASS.

CLASS lsc_ZI_HCM_ONBOARDING DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified    REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_ZI_HCM_ONBOARDING IMPLEMENTATION.
  METHOD save_modified.
    IF lcl_buffer=>mt_employee_data IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_counter) = 0.
    LOOP AT lcl_buffer=>mt_employee_data INTO DATA(ls_emp).
      lv_counter += 1.
      DATA(lv_emp_cid) = |EMP_{ lv_counter }|.
      DATA(lv_con_cid) = |CON_{ lv_counter }|.
      DATA(lv_bnk_cid) = |BNK_{ lv_counter }|.

      " 1. Create Employee master, Contact (with Address), and Bank Details in ZI_HCM_Employee
      MODIFY ENTITIES OF ZI_HCM_Employee ENTITY Employee
        CREATE SET FIELDS WITH VALUE #( (
             %cid           = lv_emp_cid
             FirstName      = ls_emp-first_name
             LastName       = ls_emp-last_name
             EmployeeStatus = 'A'
             HireDate       = cl_abap_context_info=>get_system_date( )
             Nationality    = ls_emp-nationality
             DateOfBirth    = ls_emp-date_of_birth
             PlaceOfBirth   = ls_emp-place_of_birth
             Gender         = ls_emp-gender
             MaritalStatus  = ls_emp-marital_status ) )
        CREATE BY \_Contact SET FIELDS WITH VALUE #( (
             %cid_ref = lv_emp_cid
             %target  = VALUE #( (
                  %cid            = lv_con_cid
                  PersonalEmail   = ls_emp-personal_email
                  PhoneNumber     = ls_emp-phone
                  PersonalAddress = ls_emp-address ) ) ) )
        CREATE BY \_BankDetails SET FIELDS WITH VALUE #( (
             %cid_ref = lv_emp_cid
             %target  = VALUE #( (
                  %cid          = lv_bnk_cid
                  BankName      = ls_emp-bank_name
                  AccountNumber = ls_emp-bank_account
                  Iban          = ls_emp-iban ) ) ) )
        MAPPED   DATA(lt_mapped)
        REPORTED DATA(lt_reported)
        FAILED   DATA(lt_failed).

      IF lt_failed IS INITIAL AND line_exists( lt_mapped-employee[ %cid = lv_emp_cid ] ).
        DATA(lv_new_emp_id) = lt_mapped-employee[ %cid = lv_emp_cid ]-EmployeeId.

        " 2. Link newly generated Employee ID back into Onboarding form
        UPDATE zhcm_onboardng
          SET employee_id = @lv_new_emp_id
          WHERE form_id = @ls_emp-form_id.

        " 3. Mark Application as officially HIRED ('H')
        UPDATE zhcm_applicatn
          SET overall_status = 'H'
          WHERE application_id = @ls_emp-application_id.

        " 4. Automatically generate Organizational Assignment
        SELECT SINGLE offer_id FROM zhcm_applicatn
          WHERE application_id = @ls_emp-application_id
          INTO @DATA(lv_offer_id).

        IF sy-subrc = 0.
          SELECT SINGLE title, department FROM zhcm_joboffer
            WHERE offer_id = @lv_offer_id
            INTO (@DATA(lv_job_title), @DATA(lv_dept)).

          IF sy-subrc = 0.
            " Attempt to find an active vacant position matching the job title
            SELECT SINGLE position_id, org_unit_id FROM zhcm_position
              WHERE job_title = @lv_job_title AND status <> 'F'
              INTO (@DATA(lv_pos_id), @DATA(lv_org_id)).

            " Fallback: If no vacant position found, check if any position has that title
            IF sy-subrc <> 0.
              SELECT SINGLE position_id, org_unit_id FROM zhcm_position
                WHERE job_title = @lv_job_title
                INTO (@lv_pos_id, @lv_org_id).
            ENDIF.

            " Fallback: If still no org unit found, look up org unit ID from department name
            IF lv_org_id IS INITIAL AND lv_dept IS NOT INITIAL.
              SELECT SINGLE org_unit_id FROM zhcm_orgunit
                WHERE unit_name = @lv_dept
                INTO @lv_org_id.
            ENDIF.

            " Always create Organizational Assignment
            DATA(lv_asg_id) = cl_system_uuid=>create_uuid_x16_static( ).
            INSERT zhcm_orgassign FROM @( VALUE #(
              client            = sy-mandt
              org_assignment_id = lv_asg_id
              employee_id       = lv_new_emp_id
              position_id       = lv_pos_id
              org_unit_id       = lv_org_id
              job_title         = lv_job_title
              department        = lv_dept
              valid_from        = cl_abap_context_info=>get_system_date( )
              valid_to          = '99991231'
            ) ).

            IF lv_pos_id IS NOT INITIAL.
              UPDATE zhcm_position
                SET status = 'F'
                WHERE position_id = @lv_pos_id.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD cleanup_finalize.
    CLEAR lcl_buffer=>mt_employee_data.
  ENDMETHOD.
ENDCLASS.

