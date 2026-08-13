@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Employee Core Data - Interface'
define root view entity ZI_HCM_Employee
  as select from zhcm_employee
  composition [0..*] of ZI_HCM_Contact as _Contact
  composition [0..*] of ZI_HCM_OrgAssign as _OrgAssign
  composition [0..*] of ZI_HCM_LegalCtr as _LegalContract
  composition [0..*] of ZI_HCM_BankDetl as _BankDetails
  composition [0..*] of ZI_HCM_Education as _Education
  composition [0..*] of ZI_HCM_Skill as _Skills
  composition [0..*] of ZI_HCM_Emergency as _Emergency
  composition [0..*] of ZI_HCM_Dependent as _Dependents
  composition [0..*] of ZI_HCM_Document as _Documents
{
  key employee_id              as EmployeeId,
      first_name               as FirstName,
      last_name               as LastName,
      date_of_birth             as DateOfBirth,
      place_of_birth            as PlaceOfBirth,
      marital_status            as MaritalStatus,
      nationality              as Nationality,
      gender                 as Gender,
      employee_status            as EmployeeStatus,
      photo_url               as PhotoUrl,
      hire_date               as HireDate,
      termination_date           as TerminationDate,
      @Semantics.user.createdBy: true
      created_by               as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at               as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by            as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at            as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _Contact,
      _OrgAssign,
      _LegalContract,
      _BankDetails,
      _Education,
      _Skills,
      _Emergency,
      _Dependents,
      _Documents
}
