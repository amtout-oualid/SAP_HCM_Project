@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Employee - Projection'
@Metadata.allowExtensions: true
define root view entity ZC_HCM_Employee
  provider contract transactional_query
  as projection on ZI_HCM_Employee
{
  key EmployeeId,
  
  @Search.defaultSearchElement: true
  FirstName,
  
  @Search.defaultSearchElement: true
  LastName,
  
  DateOfBirth,
  PlaceOfBirth,
  MaritalStatus,
  Nationality,
  Gender,
  
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_HCM_VH_EmpStatus', element: 'Status' } }]
  @Search.defaultSearchElement: true
  EmployeeStatus,
  
  StatusCriticality, /* EXPOSED FOR UI COLORING */
  
  PhotoUrl,
  HireDate,
  TerminationDate,
  CreatedBy,
  CreatedAt,
  LastChangedBy,
  @Semantics.systemDateTime.lastChangedAt: true
  LastChangedAt,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  LocalLastChangedAt,

  /* Associations */
  _Contact : redirected to composition child ZC_HCM_Contact,
  _BankDetails : redirected to composition child ZC_HCM_BankDetl
}
