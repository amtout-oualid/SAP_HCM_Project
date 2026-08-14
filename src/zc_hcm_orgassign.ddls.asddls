@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Org Assignment - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_OrgAssign
  as projection on ZI_HCM_OrgAssign
{
  key AssignId,
  EmployeeId,
  PositionId,
  OrgUnitId,
  JobTitle,
  Department,
  ManagerId,
  ValidFrom,
  ValidTo,
  LocalLastChangedAt,
  
  /* Associations */
  _Employee : redirected to parent ZC_HCM_Employee,
  _OrgUnit : redirected to ZC_HCM_OrgUnit,
  _Position : redirected to ZC_HCM_Position
}
