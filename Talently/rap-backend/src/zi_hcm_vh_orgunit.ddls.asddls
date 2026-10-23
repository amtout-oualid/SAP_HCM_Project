@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Organizational Units'
@Search.searchable: true
define view entity ZI_HCM_VH_OrgUnit
  as select from zhcm_orgunit
{
      @ObjectModel.text.element: ['UnitName']
      @UI.hidden: true
  key org_unit_id  as OrgUnitId,

      @EndUserText.label: 'Unit Name'
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      unit_name    as UnitName,

      @EndUserText.label: 'Org Unit No.'
      @Search.defaultSearchElement: true
      org_unit_num as OrgUnitNum,

      @EndUserText.label: 'Cost Center'
      cost_center  as CostCenter
}
where
  status <> 'I'
