@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Org Unit - Projection'
@Metadata.allowExtensions: true
define root view entity ZC_HCM_OrgUnit
  provider contract transactional_query
  as projection on ZI_HCM_OrgUnit
{
  key OrgUnitId,
  UnitName,
  ParentOrgUnitId,
  CostCenter,
  Status,
  CreatedBy,
  CreatedAt,
  LastChangedBy,
  LastChangedAt,
  LocalLastChangedAt,
  
  /* Associations */
  _Positions : redirected to composition child ZC_HCM_Position,
  _ParentUnit : redirected to ZC_HCM_OrgUnit
}
