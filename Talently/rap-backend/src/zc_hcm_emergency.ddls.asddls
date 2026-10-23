@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Emergency Contact - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_Emergency
  as projection on ZI_HCM_Emergency
{
  key EmContactId,
  EmployeeId,
  ContactName,
  Relationship,
  Phone,
  IsPrimary,
  LocalLastChangedAt,
  
  /* Associations */
  _Employee : redirected to parent ZC_HCM_Employee
}
