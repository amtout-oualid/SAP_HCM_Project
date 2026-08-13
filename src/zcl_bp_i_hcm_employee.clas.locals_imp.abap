CLASS lhc_employee DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS setDefaultStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Employee~setDefaultStatus.
ENDCLASS.

CLASS lhc_employee IMPLEMENTATION.
  METHOD setDefaultStatus.
    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee
        FIELDS ( EmployeeStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(employees).

    MODIFY ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee
        UPDATE FIELDS ( EmployeeStatus )
        WITH VALUE #( FOR emp IN employees
                       WHERE ( EmployeeStatus IS INITIAL )
                       ( %tky = emp-%tky EmployeeStatus = 'A' ) )
      REPORTED DATA(lt_reported).

    LOOP AT lt_reported-employee INTO DATA(ls_reported).
      APPEND CORRESPONDING #( ls_reported ) TO reported-employee.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

" The saver logic must be inside its own class inheriting from cl_abap_behavior_saver!
CLASS lsc_employee DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.

CLASS lsc_employee IMPLEMENTATION.
  METHOD save_modified.
    " TODO: persist all modified/created/deleted Employee + child instances to the
    " zhcm_employee/zhcm_contact/zhcm_orgassign/zhcm_legal_ctr/zhcm_bankdetl/
    " zhcm_education/zhcm_skill/zhcm_emergency/zhcm_dependent/zhcm_document DB tables
    " and send the notification email to Finance.

    IF create-employee IS NOT INITIAL.
      MODIFY zhcm_employee FROM TABLE @( VALUE #(
        FOR c IN create-employee (
          employee_id            = c-EmployeeId
          first_name             = c-FirstName
          last_name             = c-LastName
          date_of_birth           = c-DateOfBirth
          place_of_birth          = c-PlaceOfBirth
          marital_status          = c-MaritalStatus
          nationality            = c-Nationality
          gender               = c-Gender
          employee_status          = c-EmployeeStatus
          photo_url             = c-PhotoUrl
          hire_date             = c-HireDate
          termination_date         = c-TerminationDate
          created_by             = c-CreatedBy
          created_at             = c-CreatedAt
          last_changed_by          = c-LastChangedBy
          last_changed_at          = c-LastChangedAt
          local_last_changed_at      = c-LocalLastChangedAt ) ) ).
    ENDIF.

    IF update-employee IS NOT INITIAL.
      MODIFY zhcm_employee FROM TABLE @( VALUE #(
        FOR u IN update-employee (
          employee_id            = u-EmployeeId
          first_name             = u-FirstName
          last_name             = u-LastName
          date_of_birth           = u-DateOfBirth
          place_of_birth          = u-PlaceOfBirth
          marital_status          = u-MaritalStatus
          nationality            = u-Nationality
          gender               = u-Gender
          employee_status          = u-EmployeeStatus
          photo_url             = u-PhotoUrl
          hire_date             = u-HireDate
          termination_date         = u-TerminationDate
          last_changed_by          = u-LastChangedBy
          last_changed_at          = u-LastChangedAt
          local_last_changed_at      = u-LocalLastChangedAt ) ) ).
    ENDIF.

    IF delete-employee IS NOT INITIAL.
      DELETE zhcm_employee FROM TABLE @( VALUE #(
        FOR d IN delete-employee (
          employee_id = d-EmployeeId ) ) ).
    ENDIF.

    " NOTE: child entity persistence (Contact, OrgAssign, LegalContract, BankDetails,
    " Education, Skills, Emergency, Dependents, Documents) to be added here following
    " the same MODIFY/DELETE pattern, plus the Finance notification email call.
  ENDMETHOD.
ENDCLASS.

