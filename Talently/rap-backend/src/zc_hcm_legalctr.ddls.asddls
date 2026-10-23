@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Legal Contract - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_LegalCtr
  as projection on ZI_HCM_LegalCtr
{
  key ContractId,
  EmployeeId,
  NationalId,
  Ssn,
  ContractType,
  AgreedHours,
  ContractDocUrl,
  ValidFrom,
  ValidTo,
  LocalLastChangedAt,
  
  /* Associations */
  _Employee : redirected to parent ZC_HCM_Employee
}
