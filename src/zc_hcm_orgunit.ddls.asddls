@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Org Unit - Projection'
@Metadata.allowExtensions: true
define root view entity ZC_HCM_OrgUnit
  provider contract transactional_query
  as projection on ZI_HCM_OrgUnit
{
  key OrgUnitId,
  OrgUnitNum,
  UnitName,
  Description,

  @ObjectModel.text.element: ['ParentUnitName']
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_HCM_VH_OrgUnit', element: 'OrgUnitId' } }]
  ParentOrgUnitId,

  ParentUnitName,

  CostCenter,
  Budget,
  CurrencyCode,
  @ObjectModel.text.element: ['StatusText']
  Status,
  _OrgStatus.Description as StatusText,
  CreatedBy,
  CreatedAt,
  LastChangedBy,
  LastChangedAt,
  LocalLastChangedAt,

  /* Associations */
  _Positions : redirected to composition child ZC_HCM_Position,
  _ParentUnit : redirected to ZC_HCM_OrgUnit
}
