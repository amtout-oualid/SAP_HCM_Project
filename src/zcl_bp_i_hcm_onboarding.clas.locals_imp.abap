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
      ENTITY Onboarding
        FIELDS ( FirstName LastName DateOfBirth NationalId BankAccount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(forms).

    LOOP AT forms INTO DATA(form).
      IF form-FirstName IS INITIAL OR form-LastName IS INITIAL
         OR form-DateOfBirth IS INITIAL OR form-NationalId IS INITIAL.
        APPEND VALUE #( %tky = form-%tky ) TO failed-onboarding.
        APPEND VALUE #( %tky = form-%tky
                        %msg = new_message( id       = '00'
                                            number   = '001'
                                            v1       = 'Mandatory onboarding fields are missing'
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-onboarding.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD submitForm.
    MODIFY ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'S' ) )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    LOOP AT lt_failed-onboarding INTO DATA(ls_failed).
      APPEND CORRESPONDING #( ls_failed ) TO failed-onboarding.
    ENDLOOP.
    LOOP AT lt_reported-onboarding INTO DATA(ls_reported).
      APPEND CORRESPONDING #( ls_reported ) TO reported-onboarding.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD approveAndCreateEmployee.
    " TODO: deep insert into ZI_HCM_Employee + 4 children (Contact, LegalContract, BankDetails, EmergencyContact)
    MODIFY ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'A' ) )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    LOOP AT lt_failed-onboarding INTO DATA(ls_failed).
      APPEND CORRESPONDING #( ls_failed ) TO failed-onboarding.
    ENDLOOP.
    LOOP AT lt_reported-onboarding INTO DATA(ls_reported).
      APPEND CORRESPONDING #( ls_reported ) TO reported-onboarding.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD rejectForm.
    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

ENDCLASS.

