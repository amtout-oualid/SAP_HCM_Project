@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Contact - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_Contact
  as projection on ZI_HCM_Contact
{
  key ContactId,
  EmployeeId,
  PersonalAddress,
  PhoneNumber,
  PersonalEmail,
  WorkEmail,
  LocalLastChangedAt,
  
  /* Associations */
  _Employee : redirected to parent ZC_HCM_Employee
}
