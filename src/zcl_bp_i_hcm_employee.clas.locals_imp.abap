CLASS lhc_employee DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS setDefaultStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Employee~setDefaultStatus.
ENDCLASS.

CLASS lhc_employee IMPLEMENTATION.
  METHOD setDefaultStatus.
    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee FIELDS ( EmployeeStatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(employees).

    MODIFY ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee UPDATE FIELDS ( EmployeeStatus )
        WITH VALUE #( FOR emp IN employees WHERE ( EmployeeStatus IS INITIAL )
            ( %tky = emp-%tky EmployeeStatus = 'A' HireDate = cl_abap_context_info=>get_system_date( ) ) ).
  ENDMETHOD.
ENDCLASS.

CLASS lsc_employee DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.

CLASS lsc_employee IMPLEMENTATION.
  METHOD save_modified.
    " Unmanaged save is ONLY configured for Employee. Child entities
    " (Contact, BankDetails) have "persistent table" in the BDEF,
    " so the RAP framework saves them automatically!

    IF create-employee IS NOT INITIAL.
      MODIFY zhcm_employee FROM TABLE @( VALUE #( FOR c IN create-employee (
          employee_id = c-EmployeeId first_name = c-FirstName last_name = c-LastName
          date_of_birth = c-DateOfBirth nationality = c-Nationality
          employee_status = c-EmployeeStatus hire_date = c-HireDate ) ) ).
    ENDIF.

    IF update-employee IS NOT INITIAL.
      MODIFY zhcm_employee FROM TABLE @( VALUE #( FOR u IN update-employee (
          employee_id = u-EmployeeId first_name = u-FirstName last_name = u-LastName
          date_of_birth = u-DateOfBirth nationality = u-Nationality
          employee_status = u-EmployeeStatus hire_date = u-HireDate ) ) ).
    ENDIF.

    IF delete-employee IS NOT INITIAL.
      DELETE zhcm_employee FROM TABLE @( VALUE #( FOR d IN delete-employee (
          employee_id = d-EmployeeId ) ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
