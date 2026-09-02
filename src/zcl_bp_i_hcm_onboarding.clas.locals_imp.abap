CLASS lcl_buffer DEFINITION.
  PUBLIC SECTION.
    " Buffer for employee data collected during the interaction phase.
    " REASON: RAP strict(2) forbids cross-BO MODIFY ENTITIES in the interaction phase.
    " approveAndCreateEmployee fills this buffer; lsc saver reads it in save_modified.
    TYPES: BEGIN OF ty_employee_data,
             first_name      TYPE string,
             last_name       TYPE string,
             nationality     TYPE string,
             date_of_birth   TYPE d,
             place_of_birth  TYPE string,
             gender          TYPE string,
             marital_status  TYPE string,
             personal_email  TYPE string,
             phone           TYPE string,
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
    MODIFY ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding UPDATE FIELDS ( Status )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'S' ) ).

    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD approveAndCreateEmployee.
    " =========================================================
    " BUG-05 FIX:
    " ORIGINAL CODE called MODIFY ENTITIES OF ZI_HCM_Employee directly
    " inside this action (interaction phase). RAP strict(2) forbids
    " cross-BO MODIFY ENTITIES in the interaction phase, causing
    " BEHAVIOR_ILLEGAL_STATEMENT at runtime.
    "
    " FIX: Buffer the employee data in lcl_buffer here. The saver class
    " lsc_ZI_HCM_ONBOARDING reads the buffer in save_modified, which IS
    " legally permitted to call cross-BO MODIFY ENTITIES.
    " =========================================================

    " 1. Mark onboarding record as Approved
    MODIFY ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding UPDATE FIELDS ( Status )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'A' ) ).

    " 2. Read full form data for all approved records
    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_forms).

    " 3. Buffer employee data — actual employee creation happens in lsc save_modified
    LOOP AT lt_forms INTO DATA(ls_form).
      APPEND VALUE #(
        first_name     = ls_form-FirstName
        last_name      = ls_form-LastName
        nationality    = ls_form-Nationality
        date_of_birth  = ls_form-DateOfBirth
        place_of_birth = ls_form-PlaceOfBirth
        gender         = ls_form-Gender
        marital_status = ls_form-MaritalStatus
        personal_email = ls_form-PersonalEmail
        phone          = ls_form-Phone
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

*----------------------------------------------------------------------*
* SAVER CLASS — lsc_ZI_HCM_ONBOARDING
* Enabled by 'with additional save' in zi_hcm_onboarding.bdef.asbdef.
* This is the ONLY place where cross-BO MODIFY ENTITIES on ZI_HCM_Employee
* is legally permitted under RAP strict(2).
*----------------------------------------------------------------------*
CLASS lsc_ZI_HCM_ONBOARDING DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified    REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_ZI_HCM_ONBOARDING IMPLEMENTATION.
  METHOD save_modified.
    " Create Employee records from the buffered onboarding data.
    " Cross-BO MODIFY ENTITIES is legal in the save sequence.
    IF lcl_buffer=>mt_employee_data IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_counter) = 0.
    LOOP AT lcl_buffer=>mt_employee_data INTO DATA(ls_emp).
      lv_counter += 1.
      DATA(lv_emp_cid) = |EMP_{ lv_counter }|.
      DATA(lv_con_cid) = |CON_{ lv_counter }|.
      DATA(lv_bnk_cid) = |BNK_{ lv_counter }|.

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
                  %cid          = lv_con_cid
                  PersonalEmail = ls_emp-personal_email
                  PhoneNumber   = ls_emp-phone ) ) ) )
        CREATE BY \_BankDetails SET FIELDS WITH VALUE #( (
             %cid_ref = lv_emp_cid
             %target  = VALUE #( (
                  %cid          = lv_bnk_cid
                  BankName      = ls_emp-bank_name
                  AccountNumber = ls_emp-bank_account
                  Iban          = ls_emp-iban ) ) ) )
        REPORTED DATA(lt_reported)
        FAILED   DATA(lt_failed).
    ENDLOOP.
  ENDMETHOD.

  METHOD cleanup_finalize.
    " Always clear the buffer after each LUW to prevent stale data leaking into the next transaction
    CLEAR lcl_buffer=>mt_employee_data.
  ENDMETHOD.
ENDCLASS.

