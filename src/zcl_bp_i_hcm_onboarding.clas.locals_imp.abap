CLASS lhc_onboarding DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS validateMandatory FOR VALIDATE ON SAVE
      IMPORTING keys FOR Onboarding~validateMandatory.
    METHODS submitForm FOR MODIFY
      IMPORTING keys FOR ACTION Onboarding~submitForm RESULT result.
    METHODS approveAndCreateEmployee FOR MODIFY
      IMPORTING keys FOR ACTION Onboarding~approveAndCreateEmployee RESULT result.
    METHODS rejectForm FOR MODIFY
      IMPORTING keys FOR ACTION Onboarding~rejectForm RESULT result.
ENDCLASS.

CLASS lhc_onboarding IMPLEMENTATION.
  METHOD validateMandatory.
    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding FIELDS ( FirstName LastName DateOfBirth NationalId BankAccount )
      WITH CORRESPONDING #( keys ) RESULT DATA(forms).

    LOOP AT forms INTO DATA(form).
      IF form-FirstName IS INITIAL OR form-LastName IS INITIAL
         OR form-DateOfBirth IS INITIAL OR form-NationalId IS INITIAL.

        APPEND VALUE #( %tky = form-%tky ) TO failed-onboarding.
        APPEND VALUE #( %tky = form-%tky
                        %msg = new_message( id = '00' number = '004' v1 = 'Mandatory fields missing' severity = if_abap_behv_message=>severity-error ) ) TO reported-onboarding.
      ENDIF.
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
    " 1. Set Status
    MODIFY ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding UPDATE FIELDS ( Status )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'A' ) ).

    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_forms).

    " 2. Deep Insert Bridge to Employee
    LOOP AT lt_forms INTO DATA(ls_form).
      MODIFY ENTITIES OF ZI_HCM_Employee ENTITY Employee
        CREATE SET FIELDS WITH VALUE #( (
             %cid = 'EMP1'
             FirstName = ls_form-FirstName
             LastName = ls_form-LastName
             EmployeeStatus = 'A'
             HireDate = cl_abap_context_info=>get_system_date( )
             Nationality = ls_form-Nationality
             DateOfBirth = ls_form-DateOfBirth ) )
        CREATE BY \_Contact SET FIELDS WITH VALUE #( (
             %cid_ref = 'EMP1'
             %target = VALUE #( (
                  %cid = 'CON1'
                  PersonalEmail = ls_form-PersonalEmail
                  PhoneNumber = ls_form-Phone ) ) ) )
        CREATE BY \_BankDetails SET FIELDS WITH VALUE #( (
             %cid_ref = 'EMP1'
             %target = VALUE #( (
                  %cid = 'BNK1'
                  BankName = ls_form-BankName
                  AccountNumber = ls_form-BankAccount
                  Iban = ls_form-Iban ) ) ) ).
    ENDLOOP.

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
