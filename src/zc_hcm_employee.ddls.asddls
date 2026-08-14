@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Employee - Projection'
@Metadata.allowExtensions: true
define root view entity ZC_HCM_Employee
  provider contract transactional_query
  as projection on ZI_HCM_Employee
{
  key EmployeeId,
  FirstName,
  LastName,
  DateOfBirth,
  PlaceOfBirth,
  MaritalStatus,
  Nationality,
  Gender,
  EmployeeStatus,
  PhotoUrl,
  HireDate,
  TerminationDate,
  CreatedBy,
  CreatedAt,
  LastChangedBy,
  LastChangedAt,
  LocalLastChangedAt,
  
  /* Associations */
  _Contact : redirected to composition child ZC_HCM_Contact,
  _OrgAssign : redirected to composition child ZC_HCM_OrgAssign,
  _LegalContract : redirected to composition child ZC_HCM_LegalCtr,
  _BankDetails : redirected to composition child ZC_HCM_BankDetl,
  _Education : redirected to composition child ZC_HCM_Education,
  _Skills : redirected to composition child ZC_HCM_Skill,
  _Emergency : redirected to composition child ZC_HCM_Emergency,
  _Dependents : redirected to composition child ZC_HCM_Dependent,
  _Documents : redirected to composition child ZC_HCM_Document
}
