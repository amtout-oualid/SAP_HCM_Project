@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Dependent - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_Dependent
  as projection on ZI_HCM_Dependent
{
  key DependentId,
  EmployeeId,
  Name,
  Relationship,
  DateOfBirth,
  Gender,
  LocalLastChangedAt,
  
  /* Associations */
  _Employee : redirected to parent ZC_HCM_Employee
}
